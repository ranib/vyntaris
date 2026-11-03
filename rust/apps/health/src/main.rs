use adw::prelude::*;
use gtk::{gio, glib};
use serde_json::Value;
use std::cell::{Cell, RefCell};
use std::rc::Rc;
use vyntaris_core::i18n::tr;
use vyntaris_core::trf;

thread_local! {
    static APP: RefCell<Option<Rc<Doctor>>> = const { RefCell::new(None) };
}

fn main() -> glib::ExitCode {
    vyntaris_ui::run_with("org.vyntaris.Doctor", build, |_, _, _| {
        if let Some(d) = APP.with_borrow(Clone::clone) {
            d.opened();
        }
    })
}

fn tool() -> String {
    std::env::var("VYNTARIS_DOCTOR").ok().filter(|t| !t.is_empty()).unwrap_or_else(|| "/usr/lib/vyntaris/doctor".into())
}

async fn run(argv: &[String], env: &[(&str, &str)]) -> (String, String, i32) {
    let launcher = gio::SubprocessLauncher::new(gio::SubprocessFlags::STDOUT_PIPE | gio::SubprocessFlags::STDERR_PIPE);
    for (k, v) in env {
        launcher.setenv(k, v, true);
    }
    let args: Vec<&std::ffi::OsStr> = argv.iter().map(std::ffi::OsStr::new).collect();
    let Ok(p) = launcher.spawn(&args) else { return (String::new(), String::new(), -1) };
    let (out, err) = p.communicate_utf8_future(None).await.unwrap_or_default();
    let code = if p.has_exited() { p.exit_status() } else { -1 };
    (out.map(|s| s.to_string()).unwrap_or_default(), err.map(|s| s.to_string()).unwrap_or_default(), code)
}

fn level(f: &Value) -> &str {
    f["level"].as_str().unwrap_or("info")
}

fn fixes(f: &Value) -> Vec<Value> {
    f["fixes"].as_array().cloned().unwrap_or_default()
}

fn action(o: &Value) -> &str {
    o["action"].as_str().unwrap_or("")
}

fn look(level: &str) -> (&'static str, &'static str) {
    match level {
        "error" => ("dialog-error-symbolic", "error"),
        "warn" => ("dialog-warning-symbolic", "warning"),
        "ok" => ("emblem-ok-symbolic", "accent"),
        "tool" => ("user-trash-symbolic", "accent"),
        _ => ("dialog-information-symbolic", "dim-label"),
    }
}

struct Doctor {
    findings: RefCell<Vec<Value>>,
    checked: Cell<f64>,
    checking: Cell<bool>,
    fixing: Cell<bool>,
    failure: RefCell<String>,
    preparing: Cell<bool>,
    report: RefCell<Option<Value>>,

    icon: gtk::Image,
    headline: gtk::Label,
    caption: gtk::Label,
    spinner: adw::Spinner,
    fix_all: gtk::Button,
    again: gtk::Button,
    failure_label: gtk::Label,
    found: adw::PreferencesGroup,
    tools: adw::PreferencesGroup,
    clean_all: gtk::Button,
    rows: RefCell<Vec<(adw::PreferencesGroup, gtk::Widget)>>,
    sections: gtk::ListBox,
    pages: gtk::Stack,

    reporting: gtk::Revealer,
    what: adw::EntryRow,
    report_status: gtk::Label,
    see: gtk::ToggleButton,
    make: gtk::Button,
    sent: gtk::Revealer,
    sent_text: gtk::TextView,
}

impl Doctor {
    fn problems(&self) -> usize {
        self.findings.borrow().iter().filter(|f| matches!(level(f), "error" | "warn")).count()
    }

    fn fixable(&self) -> Vec<Value> {
        self.findings.borrow().iter()
            .filter(|f| matches!(level(f), "error" | "warn" | "info"))
            .filter_map(|f| fixes(f).into_iter().next())
            .filter(|o| action(o).is_empty())
            .collect()
    }

    fn opened(self: &Rc<Self>) {
        let now = glib::real_time() as f64 / 1e6;
        if now - self.checked.get() > 60.0 {
            self.check();
        }
    }

    fn check(self: &Rc<Self>) {
        if self.checking.get() {
            return;
        }
        self.checking.set(true);
        self.failure.borrow_mut().clear();
        self.show();
        let d = self.clone();
        glib::spawn_future_local(async move {
            let (out, _, code) = run(&[tool()], &[]).await;
            match serde_json::from_str::<Value>(&out) {
                Ok(r) if code == 0 => {
                    *d.findings.borrow_mut() = r["findings"].as_array().cloned().unwrap_or_default();
                    d.checked.set(r["checked"].as_f64().unwrap_or(glib::real_time() as f64 / 1e6));
                }
                _ => *d.failure.borrow_mut() = tr("The check didn't finish").into(),
            }
            d.checking.set(false);
            d.show();
        });
    }

    fn fix(self: &Rc<Self>, options: &[Value]) {
        if self.fixing.get() {
            return;
        }
        let ids = |admin: bool| -> Vec<String> {
            options.iter().filter(|o| action(o).is_empty() && o["admin"].as_bool().unwrap_or(false) == admin)
                .filter_map(|o| o["id"].as_str().map(String::from)).collect()
        };
        let (own, admin) = (ids(false), ids(true));
        for o in options.iter().filter(|o| !action(o).is_empty()) {
            act(action(o));
        }
        if own.is_empty() && admin.is_empty() {
            return;
        }
        self.fixing.set(true);
        self.show();
        let quote = |s: &str| format!("'{}'", s.replace('\'', "'\\''"));
        let mut parts = Vec::new();
        if !own.is_empty() {
            parts.push(format!("{} --fix {}", quote(&tool()), own.iter().map(|i| quote(i)).collect::<Vec<_>>().join(" ")));
        }
        if !admin.is_empty() {
            parts.push(format!("pkexec {} --fix {}", quote(&tool()), admin.iter().map(|i| quote(i)).collect::<Vec<_>>().join(" ")));
        }
        let d = self.clone();
        glib::spawn_future_local(async move {
            let (_, err, code) = run(&["sh".into(), "-c".into(), parts.join("; ")], &[]).await;
            d.fixing.set(false);
            if code != 0 && code != 126 && let Some(last) = err.trim().lines().last() {
                *d.failure.borrow_mut() = last.to_string();
            }
            d.check();
        });
    }

    fn prepare(self: &Rc<Self>) {
        let text = self.what.text().to_string();
        if self.preparing.get() || text.trim().is_empty() {
            return;
        }
        self.preparing.set(true);
        self.report.replace(None);
        self.show_report();
        let d = self.clone();
        glib::spawn_future_local(async move {
            let (out, _, _) = run(&[tool(), "--report".into()], &[("VYNTARIS_REPORT", &text)]).await;
            match serde_json::from_str::<Value>(&out) {
                Ok(r) if r["url"].is_string() => {
                    d.sent_text.buffer().set_text(r["body"].as_str().unwrap_or(""));
                    d.report.replace(Some(r));
                }
                _ => *d.failure.borrow_mut() = tr("The report couldn't be made").into(),
            }
            d.preparing.set(false);
            d.show_report();
            d.show();
        });
    }

    fn show_report(&self) {
        let ready = self.report.borrow().is_some();
        self.report_status.set_label(&if self.preparing.get() {
            tr("Gathering what the system says…")
        } else if ready {
            tr("Ready. It opens on GitHub, filled in: Submit there sends it.")
        } else {
            String::new()
        });
        self.see.set_visible(ready);
        if !ready {
            self.see.set_active(false);
        }
        self.sent.set_reveal_child(ready && self.see.is_active());
        self.see.set_label(&if self.see.is_active() { tr("Hide") } else { tr("See what's sent") });
        self.make.set_label(&if ready { tr("Open on GitHub") } else { tr("Make the report") });
        self.make.set_sensitive(!self.preparing.get() && !self.what.text().trim().is_empty());
    }

    fn show(self: &Rc<Self>) {
        let (checking, fixing) = (self.checking.get(), self.fixing.get());
        let findings = self.findings.borrow().clone();
        let problems = self.problems();
        let worst = if problems > 0 { findings.first().map_or("ok", level) } else { "ok" };
        let (icon, tint) = look(worst);
        self.icon.set_icon_name(Some(if worst == "ok" { "emblem-ok-symbolic" } else { icon }));
        for c in ["error", "warning", "accent", "dim-label"] {
            self.icon.remove_css_class(c);
        }
        self.icon.add_css_class(tint);
        self.icon.set_opacity(if checking { 0.4 } else { 1.0 });
        self.spinner.set_visible(checking || fixing);
        self.headline.set_label(&if checking && findings.is_empty() {
            tr("Looking the system over…")
        } else {
            match problems {
                0 => tr("Everything looks fine"),
                1 => tr("One thing needs a look"),
                n => trf!("{0} things need a look", n),
            }
        });
        let at = glib::DateTime::from_unix_local(self.checked.get() as i64).ok().and_then(|t| t.format("%H:%M").ok());
        self.caption.set_label(&if fixing {
            tr("Fixing…")
        } else if checking {
            tr("Checking…")
        } else {
            at.filter(|_| self.checked.get() > 0.0).map(|t| trf!("Checked at {0}", t)).unwrap_or_default()
        });
        let fixable = self.fixable().len();
        self.fix_all.set_visible(fixable > 0);
        self.fix_all.set_label(&if fixable == 1 { tr("Fix it") } else { trf!("Fix all {0}", fixable) });
        self.fix_all.set_sensitive(!fixing && !checking);
        self.again.set_sensitive(!fixing && !checking);
        let failure = self.failure.borrow().clone();
        self.failure_label.set_visible(!failure.is_empty());
        self.failure_label.set_label(&failure);

        for (group, row) in self.rows.borrow_mut().drain(..) {
            group.remove(&row);
        }
        let mut rows = Vec::new();
        for f in &findings {
            let group = if level(f) == "tool" { &self.tools } else { &self.found };
            let row = self.row(f, fixing);
            group.add(&row);
            rows.push((group.clone(), row.upcast::<gtk::Widget>()));
        }
        *self.rows.borrow_mut() = rows;
        let tools: Vec<Value> = findings.iter().filter(|f| level(f) == "tool").filter_map(|f| fixes(f).into_iter().next()).collect();
        self.found.set_visible(findings.iter().any(|f| level(f) != "tool"));
        self.tools.set_visible(findings.iter().any(|f| level(f) == "tool"));
        self.clean_all.set_visible(tools.len() > 1);
        // Clean up is in the list only when there's something to clean up.
        if let Some(row) = self.sections.row_at_index(1) {
            row.set_visible(!tools.is_empty());
            if tools.is_empty() && self.sections.selected_row().is_some_and(|r| r.index() == 1) {
                self.sections.select_row(self.sections.row_at_index(0).as_ref());
            }
        }
        self.clean_all.set_sensitive(!fixing && !checking);
    }

    fn row(self: &Rc<Self>, f: &Value, fixing: bool) -> adw::ActionRow {
        let row = adw::ActionRow::builder().use_markup(false).title(f["title"].as_str().unwrap_or(""))
            .subtitle(f["detail"].as_str().unwrap_or("")).build();
        let (icon, tint) = look(level(f));
        let image = gtk::Image::builder().icon_name(icon).valign(gtk::Align::Start).margin_top(14).css_classes([tint]).build();
        row.add_prefix(&image);
        for (i, option) in fixes(f).into_iter().enumerate() {
            let b = gtk::Button::builder().label(option["label"].as_str().map(String::from).unwrap_or_else(|| tr("Fix"))).valign(gtk::Align::Center).sensitive(!fixing).build();
            if i == 0 && level(f) != "tool" {
                b.add_css_class("suggested-action");
            }
            let d = self.clone();
            b.connect_clicked(move |_| d.fix(std::slice::from_ref(&option)));
            row.add_suffix(&b);
        }
        row
    }
}

fn act(action: &str) {
    match action {
        "updates" => vyntaris_ui::shell("updates", "open", &[]),
        "restart" => vyntaris_ui::shell("session", "leave", &["reboot"]),
        "journal" => vyntaris_ui::in_terminal("journalctl -b -p err --no-pager -o short; echo; read -rp \"Press Enter to close…\""),
        other => {
            if let Some(target) = other.strip_prefix("open:") {
                vyntaris_ui::launch(&["xdg-open", target]);
            }
        }
    }
}

fn build(app: &adw::Application) -> adw::ApplicationWindow {
    let label = |classes: &[&str]| gtk::Label::builder().xalign(0.0).wrap(true).css_classes(classes).build();
    let d = Rc::new(Doctor {
        findings: RefCell::default(),
        checked: Cell::new(0.0),
        checking: Cell::new(false),
        fixing: Cell::new(false),
        failure: RefCell::default(),
        preparing: Cell::new(false),
        report: RefCell::default(),
        icon: gtk::Image::builder().pixel_size(32).build(),
        headline: label(&["title-3"]),
        caption: label(&["dim-label"]),
        spinner: adw::Spinner::new(),
        fix_all: gtk::Button::builder().css_classes(["suggested-action", "pill"]).valign(gtk::Align::Center).build(),
        again: gtk::Button::builder().icon_name("view-refresh-symbolic").tooltip_text(tr("Check again")).build(),
        failure_label: label(&["error"]),
        found: adw::PreferencesGroup::new(),
        tools: adw::PreferencesGroup::builder().description(tr("What can be cleaned up any time, and how much it frees")).build(),
        clean_all: gtk::Button::builder().label(tr("Clean up all")).css_classes(["flat"]).valign(gtk::Align::Center).build(),
        rows: RefCell::default(),
        sections: gtk::ListBox::builder().css_classes(["navigation-sidebar"]).build(),
        pages: gtk::Stack::builder().transition_type(gtk::StackTransitionType::Crossfade).vhomogeneous(false).build(),
        reporting: gtk::Revealer::builder().transition_type(gtk::RevealerTransitionType::SlideDown).build(),
        what: adw::EntryRow::builder().title(tr("What went wrong? (e.g. the bar disappeared after plugging in a monitor)")).build(),
        report_status: label(&["dim-label", "caption"]),
        see: gtk::ToggleButton::builder().label(tr("See what's sent")).css_classes(["flat"]).build(),
        make: gtk::Button::builder().label(tr("Make the report")).css_classes(["suggested-action"]).build(),
        sent: gtk::Revealer::builder().transition_type(gtk::RevealerTransitionType::SlideDown).build(),
        sent_text: gtk::TextView::builder().editable(false).monospace(true).wrap_mode(gtk::WrapMode::WordChar)
            .top_margin(10).bottom_margin(10).left_margin(10).right_margin(10).css_classes(["card"]).build(),
    });

    let badge = gtk::Box::builder().width_request(56).height_request(56).halign(gtk::Align::Start).valign(gtk::Align::Center)
        .hexpand(false).css_classes(["card"]).build();
    d.icon.set_halign(gtk::Align::Center);
    d.icon.set_valign(gtk::Align::Center);
    d.icon.set_hexpand(false);
    badge.set_baseline_position(gtk::BaselinePosition::Center);
    badge.append(&d.icon);
    d.icon.set_margin_start(12);
    d.icon.set_margin_end(12);
    let words = gtk::Box::builder().orientation(gtk::Orientation::Vertical).spacing(2).hexpand(true).valign(gtk::Align::Center).build();
    words.append(&d.headline);
    let line = gtk::Box::new(gtk::Orientation::Horizontal, 6);
    line.append(&d.spinner);
    line.append(&d.caption);
    words.append(&line);
    let summary = gtk::Box::new(gtk::Orientation::Horizontal, 16);
    summary.append(&badge);
    summary.append(&words);
    summary.append(&d.fix_all);
    let dd = d.clone();
    d.fix_all.connect_clicked(move |_| {
        let all = dd.fixable();
        dd.fix(&all);
    });

    let report = adw::PreferencesGroup::builder().description(tr(
        "Say what went wrong and when. The report adds what the system says: its versions, what Dr. Help found, recent errors and crashes. Your name, the computer's, Wi-Fi networks and addresses are taken out.",
    )).build();
    report.add(&d.what);
    let cancel = gtk::Button::builder().label(tr("Cancel")).build();
    let buttons = gtk::Box::builder().spacing(8).margin_top(10).build();
    d.report_status.set_hexpand(true);
    buttons.append(&d.report_status);
    buttons.append(&d.see);
    buttons.append(&cancel);
    buttons.append(&d.make);
    let sent_scroll = gtk::ScrolledWindow::builder().max_content_height(260).propagate_natural_height(true).margin_top(10)
        .hscrollbar_policy(gtk::PolicyType::Never).child(&d.sent_text).build();
    d.sent.set_child(Some(&sent_scroll));
    let report_box = gtk::Box::new(gtk::Orientation::Vertical, 0);
    report_box.append(&report);
    report_box.append(&buttons);
    report_box.append(&d.sent);
    d.reporting.set_child(Some(&report_box));

    let dd = d.clone();
    cancel.connect_clicked(move |_| {
        dd.what.set_text("");
        dd.report.replace(None);
        dd.show_report();
        dd.sections.select_row(dd.sections.row_at_index(0).as_ref());
    });
    let dd = d.clone();
    d.see.connect_toggled(move |_| dd.show_report());
    let dd = d.clone();
    d.make.connect_clicked(move |_| {
        let url = dd.report.borrow().as_ref().and_then(|r| r["url"].as_str().map(String::from));
        match url {
            Some(url) => {
                vyntaris_ui::launch(&["xdg-open", &url]);
                dd.what.set_text("");
                dd.report.replace(None);
                dd.show_report();
                dd.sections.select_row(dd.sections.row_at_index(0).as_ref());
            }
            None => dd.prepare(),
        }
    });
    let dd = d.clone();
    d.what.connect_entry_activated(move |_| dd.prepare());
    let dd = d.clone();
    d.what.connect_changed(move |_| {
        dd.report.replace(None);
        dd.show_report();
    });

    let dd = d.clone();
    d.clean_all.connect_clicked(move |_| {
        let all: Vec<Value> = dd.findings.borrow().iter().filter(|f| level(f) == "tool").filter_map(|f| fixes(f).into_iter().next()).collect();
        dd.fix(&all);
    });

    // Laid out like the Store: what to look at on the left, a page of it on the right.
    let page = |children: &[&gtk::Widget]| {
        let page = gtk::Box::builder().orientation(gtk::Orientation::Vertical).spacing(18)
            .margin_top(18).margin_bottom(24).margin_start(18).margin_end(18).build();
        for w in children {
            page.append(*w);
        }
        gtk::ScrolledWindow::builder().hscrollbar_policy(gtk::PolicyType::Never).vexpand(true)
            .child(&adw::Clamp::builder().maximum_size(820).child(&page).build()).build()
    };
    let heading = |text: &str, extra: Option<&gtk::Widget>| {
        let top = gtk::Box::new(gtk::Orientation::Horizontal, 12);
        top.append(&gtk::Label::builder().label(text).xalign(0.0).hexpand(true).css_classes(["title-2"]).build());
        if let Some(w) = extra {
            top.append(w);
        }
        top.upcast::<gtk::Widget>()
    };
    d.reporting.set_reveal_child(true);
    let checks = page(&[summary.upcast_ref(), d.failure_label.upcast_ref(), d.found.upcast_ref()]);
    let cleanup = page(&[&heading(&tr("Clean up"), Some(d.clean_all.upcast_ref())), d.tools.upcast_ref()]);
    let reporting = page(&[&heading(&tr("Report a problem"), None), d.reporting.upcast_ref()]);
    for (name, icon, label, child) in [
        ("checks", "emblem-ok-symbolic", "Checks", &checks),
        ("cleanup", "user-trash-symbolic", "Clean up", &cleanup),
        ("report", "mail-send-symbolic", "Report a problem", &reporting),
    ] {
        d.pages.add_named(child, Some(name));
        let row = gtk::Box::new(gtk::Orientation::Horizontal, 10);
        row.append(&gtk::Image::from_icon_name(icon));
        row.append(&gtk::Label::builder().label(tr(label)).xalign(0.0).build());
        d.sections.append(&gtk::ListBoxRow::builder().child(&row).name(name).build());
    }
    d.sections.select_row(d.sections.row_at_index(0).as_ref());
    let dd = d.clone();
    d.sections.connect_row_selected(move |_, row| {
        let Some(row) = row else { return };
        let name = row.widget_name();
        dd.pages.set_visible_child_name(&name);
        if name == "report" {
            dd.show_report();
            dd.what.grab_focus();
        }
    });
    let side = gtk::Box::builder().orientation(gtk::Orientation::Vertical).spacing(12)
        .margin_top(12).margin_bottom(12).margin_start(12).margin_end(12).build();
    side.append(&gtk::ScrolledWindow::builder().vexpand(true).child(&d.sections).build());
    let side_bar = adw::ToolbarView::new();
    side_bar.add_top_bar(&adw::HeaderBar::builder().title_widget(&adw::WindowTitle::new("Dr. Help", "Vyntaris")).build());
    side_bar.set_content(Some(&side));
    let header = adw::HeaderBar::builder().show_title(false).build();
    header.pack_end(&d.again);
    let dd = d.clone();
    d.again.connect_clicked(move |_| dd.check());
    let content = adw::ToolbarView::new();
    content.add_top_bar(&header);
    content.set_content(Some(&d.pages));
    let view = adw::NavigationSplitView::builder()
        .sidebar(&adw::NavigationPage::builder().title("Dr. Help").child(&side_bar).build())
        .content(&adw::NavigationPage::builder().title(tr("Checks")).child(&content).build())
        .min_sidebar_width(232.0).max_sidebar_width(232.0).build();

    let win = adw::ApplicationWindow::builder().application(app).title(tr("Dr. Help")).default_width(880).default_height(660)
        .width_request(700).height_request(480).content(&view).build();
    vyntaris_ui::escape_closes(&win);
    d.show();
    d.show_report();
    APP.with_borrow_mut(|a| *a = Some(d));
    win
}
