use adw::prelude::*;
use gtk::{gio, glib};
use serde_json::{Value, json};
use std::cell::{Cell, RefCell};
use std::rc::Rc;
use std::time::Duration;
use vyntaris_core::i18n::tr;
use vyntaris_core::settings::Settings;
use vyntaris_core::trf;

thread_local! {
    static APP: RefCell<Option<Rc<Backup>>> = const { RefCell::new(None) };
}

fn main() -> glib::ExitCode {
    vyntaris_ui::run_with("org.vyntaris.Backup", build, |_, _, _| {
        if let Some(b) = APP.with_borrow(Clone::clone) {
            b.refresh();
        }
    })
}

const TOOL: &str = "vyntaris-cloud-backup";

async fn output(argv: &[&str]) -> String {
    let args: Vec<&std::ffi::OsStr> = argv.iter().map(std::ffi::OsStr::new).collect();
    let Ok(p) = gio::Subprocess::newv(&args, gio::SubprocessFlags::STDOUT_PIPE | gio::SubprocessFlags::STDERR_SILENCE) else {
        return String::new();
    };
    p.communicate_utf8_future(None).await.ok().and_then(|(out, _)| out).map(|s| s.to_string()).unwrap_or_default()
}

fn start(argv: &[&str]) {
    let args: Vec<&std::ffi::OsStr> = argv.iter().map(std::ffi::OsStr::new).collect();
    let _ = gio::Subprocess::newv(&args, gio::SubprocessFlags::STDOUT_SILENCE | gio::SubprocessFlags::STDERR_SILENCE);
}

fn size(bytes: f64) -> String {
    let units = ["B", "KB", "MB", "GB", "TB"];
    let (mut b, mut i) = (bytes, 0);
    while b >= 1024.0 && i < units.len() - 1 {
        b /= 1024.0;
        i += 1;
    }
    if i == 0 { format!("{b:.0} {}", units[i]) } else { format!("{b:.1} {}", units[i]) }
}

fn choices() -> Vec<(String, String)> {
    let mut out: Vec<(String, String)> = [
        ("documents", "Documents"), ("pictures", "Pictures"), ("desktop", "Desktop"),
        ("music", "Music"), ("videos", "Videos"), ("download", "Downloads"),
    ].iter().map(|(id, label)| (id.to_string(), tr(label))).collect();
    let system: Vec<std::path::PathBuf> = [
        glib::UserDirectory::Desktop, glib::UserDirectory::Documents, glib::UserDirectory::Downloads,
        glib::UserDirectory::Music, glib::UserDirectory::Pictures, glib::UserDirectory::Videos,
        glib::UserDirectory::Templates, glib::UserDirectory::PublicShare,
    ].into_iter().filter_map(glib::user_special_dir).collect();
    let mut others: Vec<String> = std::fs::read_dir(glib::home_dir()).into_iter().flatten().flatten()
        .filter(|e| e.file_type().is_ok_and(|t| t.is_dir()))
        .filter(|e| !system.contains(&e.path()))
        .filter_map(|e| e.file_name().into_string().ok())
        .filter(|n| !n.starts_with('.'))
        .collect();
    others.sort_by_key(|n| n.to_lowercase());
    out.extend(others.into_iter().map(|n| (format!("~/{n}"), n)));
    out
}

fn when(s: &Settings) -> String {
    let w = s.str("cloudBackup.when", "startup");
    if ["startup", "shutdown", "manual"].contains(&w.as_str()) { w } else { "startup".into() }
}

fn picked(s: &Settings) -> Vec<String> {
    s.str("cloudBackup.folders", "documents,pictures,desktop").split(',').filter(|f| !f.is_empty()).map(String::from).collect()
}

struct Backup {
    status: RefCell<Value>,
    known: Cell<bool>,
    now: RefCell<String>,
    asking_out: Cell<bool>,
    watching: RefCell<Option<glib::SourceId>>,

    icon: gtk::Image,
    headline: gtk::Label,
    caption: gtk::Label,
    act: gtk::Button,
    stop: gtk::Button,
    progress: gtk::Revealer,
    folder: gtk::Label,
    percent: gtk::Label,
    bar: vyntaris_ui::Segments,
    failure: gtk::Label,
    reconnect: gtk::Label,
    settings: adw::PreferencesGroup,
    sections: gtk::ListBox,
    pages: gtk::Stack,
    folders_count: gtk::Label,
    folders: adw::PreferencesGroup,
    folder_rows: RefCell<Vec<adw::ActionRow>>,
    space: adw::ActionRow,
    space_bar: vyntaris_ui::Segments,
    account: adw::PreferencesGroup,
    sign_out: adw::ActionRow,
}

impl Backup {
    fn connected(&self) -> bool {
        self.status.borrow()["connected"].as_bool().unwrap_or(false)
    }
    fn signing_in(&self) -> bool {
        *self.now.borrow() == "connecting"
    }
    fn backing_up(&self) -> bool {
        self.now.borrow().starts_with("backing-up")
    }
    fn busy(&self) -> bool {
        self.status.borrow()["running"].as_bool().unwrap_or(false) || self.signing_in() || self.backing_up()
    }

    fn refresh(self: &Rc<Self>) {
        let b = self.clone();
        glib::spawn_future_local(async move {
            let out = output(&[TOOL, "status"]).await;
            if let Ok(v) = serde_json::from_str::<Value>(&out) {
                b.status.replace(v);
                b.known.set(true);
            }
            b.show();
        });
    }

    fn read_now(self: &Rc<Self>) {
        let path = glib::user_runtime_dir().join("vyntaris-cloud-backup").join("now");
        let line = std::fs::read_to_string(path).unwrap_or_default().trim().to_string();
        let was = self.now.borrow().clone();
        let now = if line.starts_with("done") { String::new() } else { line };
        self.now.replace(now.clone());
        if !was.is_empty() && now.is_empty() {
            self.refresh();
        }
        self.show();
    }

    fn watch(self: &Rc<Self>) {
        if let Some(id) = self.watching.borrow_mut().take() {
            id.remove();
        }
        let (b, left) = (self.clone(), Rc::new(Cell::new(150)));
        let id = glib::timeout_add_local(Duration::from_secs(4), move || {
            b.refresh();
            left.set(left.get() - 1);
            let done = b.known.get() && !b.busy() && b.connected() && b.status.borrow()["last"].as_f64().unwrap_or(0.0) > 0.0;
            if left.get() <= 0 || done {
                b.watching.borrow_mut().take();
                return glib::ControlFlow::Break;
            }
            glib::ControlFlow::Continue
        });
        self.watching.replace(Some(id));
    }

    fn connect(self: &Rc<Self>) {
        start(&["systemd-run", "--user", "--collect", "--quiet", "--unit=vyntaris-cloud-connect", TOOL, "connect"]);
        self.watch();
    }
    fn back_up_now(self: &Rc<Self>) {
        start(&["systemd-run", "--user", "--collect", "--quiet", "--unit=vyntaris-cloud-backup-now", "--nice=19",
                "-p", "IOSchedulingClass=idle", TOOL, "run", "--now"]);
        self.status.borrow_mut()["running"] = json!(true);
        self.show();
        self.watch();
    }
    fn stop(self: &Rc<Self>) {
        start(&[TOOL, "stop"]);
        self.status.borrow_mut()["running"] = json!(false);
        self.show();
        self.watch();
    }
    fn disconnect(self: &Rc<Self>) {
        start(&[TOOL, "disconnect"]);
        self.status.replace(json!({ "connected": false }));
        self.show();
    }

    fn set_when(&self, w: &str) {
        let mut s = Settings::load();
        if when(&s) != w {
            s.set("cloudBackup.when", json!(w));
            let _ = s.save();
        }
    }
    fn pick(&self, id: &str, on: bool) {
        let mut s = Settings::load();
        let was = picked(&s);
        let now: Vec<String> = choices().into_iter().map(|(c, _)| c).filter(|c| if c == id { on } else { was.contains(c) }).collect();
        s.set("cloudBackup.folders", json!(now.join(",")));
        let _ = s.save();
        self.count_folders();
    }

    fn show_folders(self: &Rc<Self>) {
        for row in self.folder_rows.borrow_mut().drain(..) {
            self.folders.remove(&row);
        }
        let picked = picked(&Settings::load());
        let mut rows = Vec::new();
        for (id, label) in choices() {
            let check = gtk::CheckButton::builder().active(picked.contains(&id)).valign(gtk::Align::Center).build();
            let row = adw::ActionRow::builder().title(&label).use_markup(false).activatable_widget(&check).build();
            row.add_prefix(&check);
            let b = self.clone();
            check.connect_toggled(move |c| b.pick(&id, c.is_active()));
            self.folders.add(&row);
            rows.push(row);
        }
        *self.folder_rows.borrow_mut() = rows;
        self.count_folders();
    }

    fn count_folders(&self) {
        let (on, all) = (picked(&Settings::load()).len(), choices().len());
        self.folders_count.set_label(&trf!("{0} of {1}", on, all));
    }

    fn show(self: &Rc<Self>) {
        let st = self.status.borrow().clone();
        let (connected, reconnect) = (self.connected(), st["reconnect"].as_bool().unwrap_or(false));
        let (busy, failed) = (self.busy(), st["result"].as_str() == Some("failed"));
        let last = st["last"].as_f64().unwrap_or(0.0);
        let at = glib::DateTime::from_unix_local(last as i64).ok().and_then(|t| t.format("%x %H:%M").ok()).map(String::from).unwrap_or_default();

        self.caption.set_label(&if !self.known.get() {
            String::new()
        } else if !connected {
            tr("Not connected")
        } else if self.signing_in() {
            tr("Signing in…")
        } else if busy {
            tr("Backing up now…")
        } else if last <= 0.0 {
            tr("No backup yet")
        } else if failed {
            tr("Last backup didn't finish · ") + &at
        } else {
            tr("Last backup · ") + &at
        });
        for c in ["error", "dim-label"] {
            self.caption.remove_css_class(c);
        }
        self.caption.add_css_class(if failed && !busy { "error" } else { "dim-label" });
        self.icon.set_opacity(if connected { 1.0 } else { 0.5 });

        self.act.set_visible(self.known.get() && !busy);
        self.act.set_label(&if !connected { tr("Connect Google account") } else if reconnect { tr("Sign in again") } else { tr("Back up now") });
        self.stop.set_visible(busy);

        let now = self.now.borrow().clone();
        let mut parts = now.split(' ');
        let pct = parts.nth(1).and_then(|p| p.parse::<f64>().ok()).unwrap_or(0.0).clamp(0.0, 100.0);
        let folder: Vec<&str> = parts.collect();
        self.progress.set_reveal_child(busy);
        if self.backing_up() {
            self.folder.set_label(&trf!("Backing up · {0}", folder.join(" ")));
            self.percent.set_label(&format!("{}%", pct.round()));
            self.bar.set_fraction(pct / 100.0);
        } else if busy {
            self.folder.set_label(&if self.signing_in() { tr("Signing in…") } else { tr("Backing up now…") });
            self.percent.set_label("");
            self.bar.pulse();
        } else {
            self.bar.set_fraction(0.0);
        }

        let error = st["error"].as_str().unwrap_or("");
        self.failure.set_visible(connected && failed && !error.is_empty() && !busy);
        self.failure.set_label(error);
        self.reconnect.set_visible(reconnect);

        self.account.set_visible(connected);
        // Folders and When are there once signed in; until then it's the overview, to connect.
        for (i, row) in [1, 2].into_iter().filter_map(|i| self.sections.row_at_index(i).map(|r| (i, r))) {
            row.set_sensitive(connected);
            if !connected && self.sections.selected_row().is_some_and(|r| r.index() == i) {
                self.sections.select_row(self.sections.row_at_index(0).as_ref());
            }
        }
        let (used, total) = (st["used"].as_f64().unwrap_or(-1.0), st["total"].as_f64().unwrap_or(-1.0));
        self.space.set_visible(total > 0.0);
        if total > 0.0 {
            self.space.set_subtitle(&trf!("{0} of {1} used on your Drive", size(used.max(0.0)), size(total)));
            self.space_bar.set_fraction(used.max(0.0) / total);
        }
        self.sign_out.set_title(&if self.asking_out.get() { tr("Sign out (files stay)") } else { tr("Sign out") });
        if self.asking_out.get() { self.sign_out.add_css_class("error") } else { self.sign_out.remove_css_class("error") }
    }
}

fn build(app: &adw::Application) -> adw::ApplicationWindow {
    let label = |classes: &[&str]| gtk::Label::builder().xalign(0.0).wrap(true).css_classes(classes).build();
    let s = Settings::load();
    let b = Rc::new(Backup {
        status: RefCell::new(json!({})),
        known: Cell::new(false),
        now: RefCell::default(),
        asking_out: Cell::new(false),
        watching: RefCell::default(),
        icon: gtk::Image::builder().icon_name("weather-overcast-symbolic").pixel_size(32).css_classes(["accent"]).build(),
        headline: label(&["title-3"]),
        caption: label(&["dim-label"]),
        act: gtk::Button::builder().css_classes(["suggested-action", "pill"]).valign(gtk::Align::Center).build(),
        stop: gtk::Button::builder().label(tr("Stop backup")).css_classes(["destructive-action", "pill"]).valign(gtk::Align::Center).build(),
        progress: gtk::Revealer::builder().transition_type(gtk::RevealerTransitionType::SlideDown).build(),
        folder: gtk::Label::builder().xalign(0.0).hexpand(true).ellipsize(gtk::pango::EllipsizeMode::Middle).build(),
        percent: gtk::Label::builder().css_classes(["numeric", "dim-label"]).build(),
        bar: vyntaris_ui::Segments::new(),
        failure: label(&["error"]),
        reconnect: label(&["warning"]),
        settings: adw::PreferencesGroup::new(),
        sections: gtk::ListBox::builder().css_classes(["navigation-sidebar"]).build(),
        pages: gtk::Stack::builder().transition_type(gtk::StackTransitionType::Crossfade).vhomogeneous(false).build(),
        folders_count: gtk::Label::builder().css_classes(["dim-label"]).build(),
        folders: adw::PreferencesGroup::builder().description(tr(
            "The folders picked below are copied to \"Vyntaris backup\" on your Google Drive, when you pick. What you change or delete here keeps its last copy there for when you need it back. It sees only what it put there, not the rest of your Drive.",
        )).build(),
        folder_rows: RefCell::default(),
        space: adw::ActionRow::builder().title(tr("Google Drive")).build(),
        space_bar: vyntaris_ui::Segments::new(),
        account: adw::PreferencesGroup::new(),
        sign_out: adw::ActionRow::new(),
    });
    b.headline.set_label(&tr("Google Drive"));
    b.reconnect.set_label(&tr("Sign in once more: backups now go through Vyntaris's own connection to Google. Your files on Drive stay as they are."));

    let badge = gtk::Box::builder().width_request(56).height_request(56).halign(gtk::Align::Start).valign(gtk::Align::Center)
        .hexpand(false).css_classes(["card"]).build();
    b.icon.set_hexpand(true);
    b.icon.set_halign(gtk::Align::Center);
    b.icon.set_valign(gtk::Align::Center);
    badge.append(&b.icon);
    let words = gtk::Box::builder().orientation(gtk::Orientation::Vertical).spacing(2).hexpand(true).valign(gtk::Align::Center).build();
    words.append(&b.headline);
    words.append(&b.caption);
    let summary = gtk::Box::new(gtk::Orientation::Horizontal, 16);
    summary.append(&badge);
    summary.append(&words);
    summary.append(&b.act);
    summary.append(&b.stop);
    let bb = b.clone();
    b.act.connect_clicked(move |_| {
        let st = bb.status.borrow().clone();
        if !st["connected"].as_bool().unwrap_or(false) || st["reconnect"].as_bool().unwrap_or(false) { bb.connect() } else { bb.back_up_now() }
    });
    let bb = b.clone();
    b.stop.connect_clicked(move |_| bb.stop());

    let line = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    line.append(&b.folder);
    line.append(&b.percent);
    let under_way = gtk::Box::builder().orientation(gtk::Orientation::Vertical).spacing(8).css_classes(["card"]).build();
    for w in [line.upcast_ref::<gtk::Widget>(), b.bar.widget().upcast_ref()] {
        w.set_margin_start(16);
        w.set_margin_end(16);
        under_way.append(w);
    }
    line.set_margin_top(14);
    b.bar.widget().set_margin_bottom(16);
    b.progress.set_child(Some(&under_way));

    // When it backs up: one of three, each saying what it means (solid radios, like the Store's lists).
    let w = when(&s);
    let mut first: Option<gtk::CheckButton> = None;
    for (value, text, about) in [
        ("startup", tr("At every start"), tr("A few minutes after the computer starts, once each time.")),
        ("shutdown", tr("At shutdown"), tr("As you shut down or restart, before the computer goes off. You can skip it there.")),
        ("manual", tr("Only by hand"), tr("Only when you press Back up now.")),
    ] {
        let radio = gtk::CheckButton::builder().active(w == value).valign(gtk::Align::Center).build();
        match &first {
            Some(f) => radio.set_group(Some(f)),
            None => first = Some(radio.clone()),
        }
        let row = adw::ActionRow::builder().title(text).subtitle(about).activatable_widget(&radio).build();
        row.add_prefix(&radio);
        let (bb, v) = (b.clone(), value.to_string());
        radio.connect_toggled(move |r| if r.is_active() { bb.set_when(&v) });
        b.settings.add(&row);
    }

    b.show_folders();
    b.space_bar.widget().set_width_request(140);
    b.space.add_suffix(b.space_bar.widget());

    let browse = adw::ActionRow::builder().title(tr("Browse backup")).activatable(true).build();
    browse.add_prefix(&gtk::Image::from_icon_name("folder-symbolic"));
    browse.add_suffix(&gtk::Image::from_icon_name("go-next-symbolic"));
    browse.connect_activated(|_| start(&[TOOL, "browse"]));
    b.account.add(&browse);
    b.account.add(&b.space);
    b.sign_out.set_activatable(true);
    b.sign_out.add_prefix(&gtk::Image::from_icon_name("system-log-out-symbolic"));
    b.account.add(&b.sign_out);
    let bb = b.clone();
    b.sign_out.connect_activated(move |_| {
        if !bb.asking_out.get() {
            bb.asking_out.set(true);
            bb.show();
            let b2 = bb.clone();
            glib::timeout_add_local_once(Duration::from_secs(5), move || {
                b2.asking_out.set(false);
                b2.show();
            });
            return;
        }
        bb.asking_out.set(false);
        bb.disconnect();
    });

    // Laid out like the Store: what it is on the left, a page of it on the right.
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
    b.account.set_title(&tr("Account"));
    let overview = page(&[summary.upcast_ref(), b.progress.upcast_ref(), b.failure.upcast_ref(), b.reconnect.upcast_ref(), b.account.upcast_ref()]);
    let folders = page(&[&heading(&tr("Folders backed up"), Some(b.folders_count.upcast_ref())), b.folders.upcast_ref()]);
    let schedule = page(&[&heading(&tr("When"), None), b.settings.upcast_ref()]);
    for (name, icon, label, child) in [
        ("overview", "weather-overcast-symbolic", "Overview", &overview),
        ("folders", "folder-symbolic", "Folders", &folders),
        ("when", "alarm-symbolic", "When", &schedule),
    ] {
        b.pages.add_named(child, Some(name));
        let row = gtk::Box::new(gtk::Orientation::Horizontal, 10);
        row.append(&gtk::Image::from_icon_name(icon));
        row.append(&gtk::Label::builder().label(tr(label)).xalign(0.0).build());
        b.sections.append(&gtk::ListBoxRow::builder().child(&row).name(name).build());
    }
    b.sections.select_row(b.sections.row_at_index(0).as_ref());
    let bb = b.clone();
    b.sections.connect_row_selected(move |_, row| {
        if let Some(row) = row {
            bb.pages.set_visible_child_name(&row.widget_name());
        }
    });
    let side = gtk::Box::builder().orientation(gtk::Orientation::Vertical).spacing(12)
        .margin_top(12).margin_bottom(12).margin_start(12).margin_end(12).build();
    side.append(&gtk::ScrolledWindow::builder().vexpand(true).child(&b.sections).build());
    let side_bar = adw::ToolbarView::new();
    side_bar.add_top_bar(&adw::HeaderBar::builder().title_widget(&adw::WindowTitle::new(&tr("Backup"), &tr("Google Drive"))).build());
    side_bar.set_content(Some(&side));
    let content = adw::ToolbarView::new();
    content.add_top_bar(&adw::HeaderBar::builder().show_title(false).build());
    content.set_content(Some(&b.pages));
    let view = adw::NavigationSplitView::builder()
        .sidebar(&adw::NavigationPage::builder().title(tr("Backup")).child(&side_bar).build())
        .content(&adw::NavigationPage::builder().title(tr("Google Drive")).child(&content).build())
        .min_sidebar_width(232.0).max_sidebar_width(232.0).build();

    let now = gio::File::for_path(glib::user_runtime_dir().join("vyntaris-cloud-backup").join("now"));
    if let Ok(monitor) = now.monitor_file(gio::FileMonitorFlags::NONE, gio::Cancellable::NONE) {
        let bb = b.clone();
        monitor.connect_changed(move |_, _, _, _| bb.read_now());
        std::mem::forget(monitor);
    }

    let win = adw::ApplicationWindow::builder().application(app).title(tr("Backup")).default_width(880).default_height(660)
        .width_request(700).height_request(480).content(&view).build();
    vyntaris_ui::escape_closes(&win);
    b.read_now();
    b.show();
    b.refresh();
    APP.with_borrow_mut(|a| *a = Some(b));
    win
}
