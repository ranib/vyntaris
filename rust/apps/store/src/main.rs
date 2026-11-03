use vyntaris_core::i18n::tr;
use vyntaris_core::trf;
use adw::prelude::*;
use gtk::{gio, glib};
use serde_json::Value;
use std::cell::{Cell, RefCell};
use std::collections::HashSet;
use std::path::PathBuf;
use std::rc::Rc;
use std::sync::LazyLock;
use std::time::Duration;

thread_local! {
    static STORE: RefCell<Option<Rc<Store>>> = const { RefCell::new(None) };
}

fn main() -> glib::ExitCode {
    vyntaris_ui::run_with("org.vyntaris.Store", build, |_, call, arg| {
        if let Some(s) = STORE.with_borrow(Clone::clone) {
            s.opened();
            if call == "search" {
                s.search.set_text(arg);
                s.search.set_position(-1);
            }
        }
    })
}

const POPULAR: &[&str] = &["firefox", "chromium", "thunderbird", "libreoffice-fresh", "code", "gimp", "inkscape",
    "krita", "blender", "kdenlive", "obs-studio", "vlc", "audacity", "steam", "discord", "telegram-desktop",
    "signal-desktop", "keepassxc", "qbittorrent", "prismlauncher", "shotcut", "darktable"];

const SECTIONS: &[(&str, &str, &str)] = &[
    ("popular", "Popular", "starred-symbolic"),
    ("installed", "Installed", "object-select-symbolic"),
    ("internet", "Internet", "network-workgroup-symbolic"),
    ("office", "Office", "x-office-document-symbolic"),
    ("graphics", "Graphics", "image-x-generic-symbolic"),
    ("media", "Music & video", "audio-x-generic-symbolic"),
    ("games", "Games", "input-gaming-symbolic"),
    ("development", "Development", "utilities-terminal-symbolic"),
    ("education", "Education & science", "accessories-dictionary-symbolic"),
    ("utilities", "Utilities", "applications-utilities-symbolic"),
    ("system", "System", "emblem-system-symbolic"),
];

const LAUNCHERS: &[&str] = &["steam", "net.lutris.Lutris", "lutris", "com.heroicgameslauncher.hgl", "heroic"];

fn catalogue() -> PathBuf {
    vyntaris_core::paths::cache_home().join("vyntaris").join("store.json")
}

fn indexer() -> String {
    std::env::var("VYNTARIS_STORE_INDEX").ok().filter(|t| !t.is_empty()).unwrap_or_else(|| "/usr/lib/vyntaris/store-index".into())
}

fn s<'a>(a: &'a Value, k: &str) -> &'a str {
    a[k].as_str().unwrap_or("")
}

async fn output(argv: &[&str]) -> (String, i32) {
    let args: Vec<&std::ffi::OsStr> = argv.iter().map(std::ffi::OsStr::new).collect();
    let Ok(p) = gio::Subprocess::newv(&args, gio::SubprocessFlags::STDOUT_PIPE | gio::SubprocessFlags::STDERR_SILENCE) else {
        return (String::new(), -1);
    };
    let (out, _) = p.communicate_utf8_future(None).await.unwrap_or_default();
    (out.map(|o| o.to_string()).unwrap_or_default(), if p.has_exited() { p.exit_status() } else { -1 })
}

struct Parts {
    install: gtk::Button,
    open: gtk::Button,
    remove: gtk::Button,
    working: gtk::Box,
    working_label: gtk::Label,
    bar: vyntaris_ui::Segments,
    installed: bool,
}

struct Store {
    apps: RefCell<Vec<Value>>,
    aur: RefCell<String>,
    aur_on: Cell<bool>,
    getting_helper: Cell<bool>,
    aur_results: RefCell<Vec<Value>>,
    aur_asked: Cell<u64>,
    foreign: RefCell<HashSet<String>>,
    section: RefCell<String>,
    query: RefCell<String>,
    busy: RefCell<String>,
    busy_what: RefCell<String>,
    progress: Cell<f64>,
    indexing: Cell<bool>,
    aur_waiting: RefCell<String>,
    rows: RefCell<Vec<(String, Parts)>>,
    aur_delay: RefCell<Option<glib::SourceId>>,
    win: RefCell<Option<adw::ApplicationWindow>>,
    monitor: RefCell<Option<gio::FileMonitor>>,

    title: adw::WindowTitle,
    sections: gtk::ListBox,
    search: gtk::SearchEntry,
    heading: gtk::Label,
    count: gtk::Label,
    message: gtk::Label,
    list: gtk::ListBox,
    aur_box: gtk::Box,
    aur_list: gtk::ListBox,
    aur_offer: gtk::Box,
    empty: gtk::Label,
}

fn day(unix: i64) -> String {
    glib::DateTime::from_unix_local(unix).ok().filter(|_| unix > 0)
        .and_then(|d| d.format("%-d %b %Y").ok()).map(|d| d.to_string()).unwrap_or_default()
}

fn now() -> i64 {
    glib::DateTime::now_local().map(|d| d.to_unix()).unwrap_or(0)
}

impl Store {

    fn load(&self) {
        let apps = std::fs::read(catalogue()).ok().and_then(|d| serde_json::from_slice::<Value>(&d).ok())
            .and_then(|v| v["apps"].as_array().cloned()).unwrap_or_default();
        *self.apps.borrow_mut() = apps;
    }

    fn opened(self: &Rc<Self>) {
        let fresh = std::fs::metadata(catalogue()).and_then(|m| m.modified()).ok()
            .and_then(|t| t.elapsed().ok()).is_some_and(|age| age < Duration::from_secs(86400));
        if !fresh && !self.indexing.get() {
            self.index(&[]);
        }
        self.list_foreign();
        self.read_aur_setting();
        self.search.grab_focus();
    }

    fn read_aur_setting(self: &Rc<Self>) {
        let on = vyntaris_core::settings::Settings::load().bool("apps.aur", false);
        if on != self.aur_on.get() {
            self.aur_on.set(on);
            self.helper_shown();
            self.query_changed();
            self.helper_if_missing();
        }
    }

    // The AUR on but no helper to build with (an ISO install tries in its chroot, often offline): get yay now, once.
    fn helper_if_missing(self: &Rc<Self>) {
        let missing = self.aur.borrow().is_empty();
        if !missing || !self.aur_on.get() || self.getting_helper.get() {
            return;
        }
        self.getting_helper.set(true);
        self.say(&tr("Setting up the AUR: its helper (yay) is installed once, then searches ask the AUR too."), false);
        let script = vyntaris_core::paths::shell_dir().join("scripts/aur-helper.sh").display().to_string();
        let job = gio::Subprocess::newv(&[std::ffi::OsStr::new(&script)], gio::SubprocessFlags::NONE);
        let st = self.clone();
        glib::spawn_future_local(async move {
            if let Ok(p) = job {
                let _ = p.wait_future().await;
            }
            let helper = ["yay", "paru"].into_iter().find(|h| vyntaris_ui::which(h)).unwrap_or("");
            *st.aur.borrow_mut() = helper.to_string();
            st.getting_helper.set(false);
            if helper.is_empty() {
                st.say(&tr("The AUR's helper (yay) couldn't be installed, so the Store shows only Arch's apps. Is there internet?"), true);
            } else {
                st.say("", false);
            }
            st.helper_shown();
            st.query_changed();
        });
    }

    fn helper_shown(&self) {
        let on = !self.aur.borrow().is_empty() && self.aur_on.get();
        self.title.set_subtitle(&if on { tr("Arch · AUR") } else { tr("Arch") });
    }

    fn index(self: &Rc<Self>, extra: &[&str]) {
        self.indexing.set(true);
        self.show();
        let (st, extra): (Rc<Self>, Vec<String>) = (self.clone(), extra.iter().map(|e| e.to_string()).collect());
        glib::spawn_future_local(async move {
            let cat = catalogue().display().to_string();
            let mut argv = vec![indexer(), cat];
            argv.extend(extra);
            output(&argv.iter().map(String::as_str).collect::<Vec<_>>()).await;
            st.indexing.set(false);
            st.load();
            st.show();
        });
    }

    fn list_foreign(self: &Rc<Self>) {
        let st = self.clone();
        glib::spawn_future_local(async move {
            let (out, _) = output(&["pacman", "-Qqm"]).await;
            *st.foreign.borrow_mut() = out.lines().map(String::from).collect();
            let foreign = st.foreign.borrow().clone();
            for a in st.aur_results.borrow_mut().iter_mut() {
                a["installed"] = Value::Bool(foreign.contains(s(a, "pkg")));
            }
            st.update_rows();
        });
    }

    fn shown(&self) -> Vec<Value> {
        let q = self.query.borrow().trim().to_lowercase();
        let apps = self.apps.borrow();
        if !q.is_empty() {
            let mut scored: Vec<(u8, &Value)> = apps.iter().filter_map(|a| {
                let n = s(a, "name").to_lowercase();
                let score = if n.starts_with(&q) { 0 } else if n.contains(&q) { 1 } else if s(a, "pkg").to_lowercase().contains(&q) { 2 }
                    else if s(a, "summary").to_lowercase().contains(&q) { 3 } else { return None };
                Some((score, a))
            }).collect();
            scored.sort_by_key(|(score, _)| *score);
            return scored.into_iter().take(120).map(|(_, a)| a.clone()).collect();
        }
        match self.section.borrow().as_str() {
            "popular" => POPULAR.iter().filter_map(|p| apps.iter().find(|a| s(a, "pkg") == *p).cloned()).collect(),
            "installed" => apps.iter().filter(|a| a["installed"].as_bool() == Some(true)).cloned().collect(),
            section => apps.iter().filter(|a| s(a, "group") == section).cloned().collect(),
        }
    }

    fn aur_shown(&self, repo: &[Value]) -> Vec<Value> {
        if self.query.borrow().trim().is_empty() {
            return Vec::new();
        }
        let names: HashSet<&str> = repo.iter().map(|a| s(a, "pkg")).collect();
        self.aur_results.borrow().iter().filter(|a| !names.contains(s(a, "pkg"))).cloned().collect()
    }

    fn show(self: &Rc<Self>) {
        let searching = !self.query.borrow().trim().is_empty();
        let repo = self.shown();
        let aur = self.aur_shown(&repo);
        self.heading.set_label(&if searching {
            tr("Search")
        } else {
            SECTIONS.iter().find(|(id, _, _)| *id == *self.section.borrow()).map_or(String::new(), |(_, l, _)| tr(l))
        });
        let n = repo.len() + aur.len();
        self.count.set_label(&if self.indexing.get() && self.apps.borrow().is_empty() {
            String::new()
        } else {
            if n == 1 { tr("1 app") } else { trf!("{0} apps", n) }
        });
        self.list.remove_all();
        self.aur_list.remove_all();
        self.rows.borrow_mut().clear();
        for a in &repo {
            self.list.append(&self.row(a));
        }
        for a in &aur {
            self.aur_list.append(&self.row(a));
        }
        self.list.set_visible(!repo.is_empty());
        self.aur_box.set_visible(!aur.is_empty());
        self.aur_offer.set_visible(searching && !self.aur.borrow().is_empty() && !self.aur_on.get());
        self.empty.set_visible(n == 0);
        let q = self.query.borrow().trim().to_string();
        self.empty.set_label(&if self.apps.borrow().is_empty() {
            if self.indexing.get() { tr("Getting the list of apps…").into() } else { tr("No apps yet").into() }
        } else if !q.is_empty() {
            trf!("Nothing called “{0}”", q)
        } else {
            tr("Nothing here yet").into()
        });
        self.update_rows();
    }

    fn icon(a: &Value) -> gtk::Image {
        let icon = s(a, "icon");
        let image = if let Some(name) = icon.strip_prefix("theme:") {
            let theme = gtk::IconTheme::for_display(&gtk::gdk::Display::default().expect("a display"));
            gtk::Image::from_icon_name(if theme.has_icon(name) { name } else { "application-x-executable" })
        } else if !icon.is_empty() && std::path::Path::new(icon).exists() {
            gtk::Image::from_file(icon)
        } else {
            gtk::Image::from_icon_name("application-x-executable")
        };
        image.set_pixel_size(40);
        image.add_css_class("icon-dropshadow");
        image
    }

    fn row(self: &Rc<Self>, a: &Value) -> adw::ExpanderRow {
        let row = adw::ExpanderRow::builder().title(glib::markup_escape_text(s(a, "name"))).subtitle(glib::markup_escape_text(s(a, "summary")))
            .subtitle_lines(1).build();
        row.add_prefix(&Self::icon(a));
        let aur = s(a, "source") == "aur";
        let badge = gtk::Label::builder().label(if aur { tr("AUR") } else { tr("Arch") }).valign(gtk::Align::Center)
            .css_classes(["vyntaris-badge"]).build();
        if aur {
            badge.add_css_class("warning");
        }
        row.add_suffix(&badge);

        let install = gtk::Button::builder().label(tr("Install")).css_classes(["suggested-action"]).valign(gtk::Align::Center).build();
        let open = gtk::Button::builder().label(tr("Open")).valign(gtk::Align::Center).build();
        let working_label = gtk::Label::builder().css_classes(["caption", "dim-label"]).xalign(1.0).build();
        let bar = vyntaris_ui::Segments::new();
        bar.widget().set_width_request(120);
        let working = gtk::Box::builder().orientation(gtk::Orientation::Vertical).spacing(4).valign(gtk::Align::Center).build();
        working.append(&working_label);
        working.append(bar.widget());
        row.add_suffix(&working);
        row.add_suffix(&open);
        row.add_suffix(&install);

        let desc = gtk::Label::builder().label(s(a, "desc")).wrap(true).xalign(0.0).css_classes(["dim-label"])
            .visible(!s(a, "desc").is_empty()).build();
        let pkg = gtk::Label::builder().label(s(a, "pkg")).xalign(0.0).hexpand(true).css_classes(["monospace", "caption", "dim-label"]).build();
        let remove = gtk::Button::builder().label(tr("Remove")).css_classes(["destructive-action"]).build();
        let foot = gtk::Box::new(gtk::Orientation::Horizontal, 10);
        foot.append(&pkg);
        foot.append(&remove);
        let more = gtk::Box::builder().orientation(gtk::Orientation::Vertical).spacing(10)
            .margin_top(12).margin_bottom(12).margin_start(64).margin_end(12).build();
        more.append(&desc);
        more.append(&foot);
        row.add_row(&more);

        for (button, what) in [(&install, "install"), (&remove, "remove")] {
            let (st, a) = (self.clone(), a.clone());
            button.connect_clicked(move |_| st.run(&a, what));
        }
        let (st, a2) = (self.clone(), a.clone());
        open.connect_clicked(move |_| st.open(&a2));
        let installed = a["installed"].as_bool().unwrap_or(false);
        self.rows.borrow_mut().push((s(a, "pkg").to_string(), Parts { install, open, remove, working, working_label, bar, installed }));
        row
    }

    fn update_rows(&self) {
        let busy = self.busy.borrow().clone();
        let what = self.busy_what.borrow().clone();
        let p = self.progress.get();
        let foreign = self.foreign.borrow();
        for (pkg, parts) in self.rows.borrow().iter() {
            let working = *pkg == busy;
            let installed = parts.installed || foreign.contains(pkg);
            parts.working.set_visible(working);
            if !working {
                parts.bar.set_fraction(0.0);
            }
            parts.open.set_visible(!working && installed);
            parts.install.set_visible(!working && !installed);
            parts.install.set_sensitive(busy.is_empty());
            parts.remove.set_visible(installed && !working);
            parts.remove.set_sensitive(busy.is_empty());
            if working {
                let doing = if what == "install" { tr("Installing") } else { tr("Removing") };
                parts.working_label.set_label(&if p >= 0.0 { format!("{doing} {}%", (p * 100.0).round()) } else { format!("{doing}…") });
                if p >= 0.0 {
                    parts.bar.set_fraction(p);
                } else {
                    parts.bar.pulse();
                }
            }
        }
    }

    fn say(&self, text: &str, bad: bool) {
        self.message.set_label(text);
        self.message.set_visible(!text.is_empty());
        if bad { self.message.add_css_class("error") } else { self.message.remove_css_class("error") }
    }

    fn query_changed(self: &Rc<Self>) {
        *self.query.borrow_mut() = self.search.text().to_string();
        self.aur_results.borrow_mut().clear();
        let q = self.query.borrow().trim().to_string();
        if q.is_empty() {
            let current = SECTIONS.iter().position(|(id, _, _)| *id == *self.section.borrow()).unwrap_or(0);
            self.sections.select_row(self.sections.row_at_index(current as i32).as_ref());
        } else {
            self.sections.unselect_all();
        }
        self.show();
        if let Some(old) = self.aur_delay.borrow_mut().take() {
            old.remove();
        }
        if self.aur.borrow().is_empty() || !self.aur_on.get() || q.chars().count() < 2 {
            return;
        }
        let st = self.clone();
        let id = glib::timeout_add_local_once(Duration::from_millis(350), move || {
            st.aur_delay.borrow_mut().take();
            st.ask_aur(q);
        });
        *self.aur_delay.borrow_mut() = Some(id);
    }

    fn ask_aur(self: &Rc<Self>, q: String) {
        let asked = self.aur_asked.get() + 1;
        self.aur_asked.set(asked);
        let st = self.clone();
        glib::spawn_future_local(async move {
            let url = format!("https://aur.archlinux.org/rpc/v5/search/{}?by=name-desc", glib::Uri::escape_string(&q, None, false));
            let (out, _) = output(&["curl", "-fsS", "--max-time", "8", &url]).await;
            if st.aur_asked.get() != asked {
                return;
            }
            let mut found = serde_json::from_str::<Value>(&out).ok().and_then(|v| v["results"].as_array().cloned()).unwrap_or_default();
            found.sort_by(|a, b| b["Popularity"].as_f64().unwrap_or(0.0).total_cmp(&a["Popularity"].as_f64().unwrap_or(0.0)));
            let foreign = st.foreign.borrow().clone();
            *st.aur_results.borrow_mut() = found.iter().take(30).map(|r| {
                let name = s(r, "Name");
                let (votes, modified) = (r["NumVotes"].as_i64().unwrap_or(0), r["LastModified"].as_i64().unwrap_or(0));
                let desc = format!("{}{}{}", if r["OutOfDate"].is_null() { String::new() } else { tr("Flagged out of date. ") },
                    trf!("{0} votes · version {1}", votes, s(r, "Version")),
                    if r["Maintainer"].is_string() { trf!(" · kept by {0}", s(r, "Maintainer")) } else { tr(" · without a maintainer") });
                let summary = format!("{} · {}", trf!("{0} votes · changed {1}", votes, day(modified)), s(r, "Description"));
                serde_json::json!({"id": name, "name": name, "summary": summary, "desc": desc, "source": "aur", "pkg": name,
                    "icon": format!("theme:{name}"), "group": "", "installed": foreign.contains(name),
                    "votes": votes, "modified": modified, "submitted": r["FirstSubmitted"].as_i64().unwrap_or(0),
                    "maintainer": r["Maintainer"].as_str(), "outdated": !r["OutOfDate"].is_null()})
            }).collect();
            st.show();
        });
    }

    fn run(self: &Rc<Self>, a: &Value, what: &str) {
        if !self.busy.borrow().is_empty() {
            return;
        }
        let pkg = s(a, "pkg").to_string();
        static NAME: LazyLock<regex::Regex> = LazyLock::new(|| regex::Regex::new(r"^[a-z0-9@._+-]+$").unwrap());
        if !NAME.is_match(&pkg) {
            return;
        }
        if s(a, "source") == "aur" && what == "install" {
            self.confirm_aur(a);
            return;
        }
        self.start(a, what);
    }

    fn confirm_aur(self: &Rc<Self>, a: &Value) {
        let (name, pkg) = (s(a, "name"), s(a, "pkg").to_string());
        let votes = a["votes"].as_i64().unwrap_or(0);
        let modified = a["modified"].as_i64().unwrap_or(0);
        let mut facts = vec![
            trf!("Votes: {0}", votes),
            a["maintainer"].as_str().map_or_else(|| tr("Kept by no one"), |m| trf!("Kept by {0}", m)),
            trf!("Recipe last changed: {0}", day(modified)),
            trf!("First uploaded: {0}", day(a["submitted"].as_i64().unwrap_or(0))),
        ];
        let mut cautions = Vec::new();
        if a["maintainer"].is_null() {
            cautions.push(tr("No one keeps it: anyone can take it over."));
        }
        if modified > 0 && now() - modified < 7 * 86400 {
            cautions.push(tr("Its recipe changed in the last week. A harmful change is most often new."));
        }
        if votes < 10 {
            cautions.push(tr("Few people use it."));
        }
        if a["outdated"].as_bool() == Some(true) {
            cautions.push(tr("It's flagged out of date, so it may not build."));
        }
        facts.extend(cautions.iter().map(|c| format!("⚠ {c}")));
        let body = format!("{}\n\n{}",
            tr("Anyone can upload a recipe to the AUR, and Arch doesn't check them. Building one runs it on this computer as you, and what it installs gets the system's rights. Install it only if you trust it: its page shows the recipe and what others say."),
            facts.join("\n"));
        let dialog = adw::AlertDialog::new(Some(&trf!("Build {0} from the AUR?", name)), Some(&body));
        dialog.add_responses(&[("cancel", &tr("Cancel")), ("page", &tr("See its page")), ("build", &tr("Build and install"))]);
        dialog.set_response_appearance("build", adw::ResponseAppearance::Destructive);
        dialog.set_default_response(Some("cancel"));
        dialog.set_close_response("cancel");
        let (st, a) = (self.clone(), a.clone());
        dialog.connect_response(None, move |_, response| match response {
            "build" => st.start(&a, "install"),
            "page" => vyntaris_ui::launch(&["xdg-open", &format!("https://aur.archlinux.org/packages/{pkg}")]),
            _ => {}
        });
        dialog.present(self.win.borrow().as_ref());
    }

    fn offer_aur(self: &Rc<Self>) {
        let dialog = adw::AlertDialog::new(Some(&tr("Search the AUR too?")), Some(&tr("The AUR is where Arch's users share recipes for apps Arch doesn't have. Anyone can upload one and Arch doesn't check them, so one could install something harmful. The Store shows each one's votes and when it last changed, and asks before it builds one. You can turn it off again in Settings → Apps.")));
        dialog.add_responses(&[("cancel", &tr("Cancel")), ("on", &tr("Turn on the AUR"))]);
        dialog.set_response_appearance("on", adw::ResponseAppearance::Suggested);
        dialog.set_default_response(Some("cancel"));
        dialog.set_close_response("cancel");
        let st = self.clone();
        dialog.connect_response(None, move |_, response| {
            if response != "on" {
                return;
            }
            let mut settings = vyntaris_core::settings::Settings::load();
            settings.set("apps.aur", Value::Bool(true));
            if let Err(e) = settings.save() {
                st.say(&trf!("That didn't work: {0}", e), true);
                return;
            }
            st.aur_on.set(true);
            st.helper_shown();
            st.query_changed();
        });
        dialog.present(self.win.borrow().as_ref());
    }

    fn start(self: &Rc<Self>, a: &Value, what: &str) {
        let pkg = s(a, "pkg").to_string();
        if s(a, "source") == "aur" && what == "install" {
            let script = vyntaris_core::paths::shell_dir().join("scripts/aur-install.sh").display().to_string();
            let (unit, description) = (format!("--unit=vyntaris-aur-{pkg}"), format!("--description=Installing {pkg} from the AUR"));
            let helper = self.aur.borrow().clone();
            let argv = ["systemd-run", "--user", "--quiet", "--collect", &unit, &description, "--", &script, &helper, &pkg];
            let _ = gio::Subprocess::newv(&argv.iter().map(std::ffi::OsStr::new).collect::<Vec<_>>(), gio::SubprocessFlags::NONE);
            self.say(&trf!("Building {0} from the AUR (a recipe from the community, not Arch's own). It's installed when the build is done.",
                s(a, "name")), false);
            *self.aur_waiting.borrow_mut() = pkg;
            self.watch_aur(450);
            return;
        }
        *self.busy.borrow_mut() = pkg.clone();
        *self.busy_what.borrow_mut() = what.to_string();
        self.progress.set(-1.0);
        self.say("", false);
        self.update_rows();
        let argv: Vec<&str> = if what == "install" {
            vec!["pkexec", "pacman", "-S", "--noconfirm", "--needed", &pkg]
        } else {
            vec!["pkexec", "pacman", "-Rns", "--noconfirm", &pkg]
        };
        let args: Vec<&std::ffi::OsStr> = argv.iter().map(std::ffi::OsStr::new).collect();
        let job = gio::Subprocess::newv(&args, gio::SubprocessFlags::STDOUT_PIPE | gio::SubprocessFlags::STDERR_MERGE);
        let (st, a, what) = (self.clone(), a.clone(), what.to_string());
        let pulse = {
            let st = self.clone();
            glib::timeout_add_local(Duration::from_millis(120), move || {
                if st.busy.borrow().is_empty() {
                    return glib::ControlFlow::Break;
                }
                if st.progress.get() < 0.0 {
                    st.update_rows();
                }
                glib::ControlFlow::Continue
            })
        };
        glib::spawn_future_local(async move {
            let mut said = String::new();
            let code = match job {
                Ok(p) => {
                    if let Some(out) = p.stdout_pipe() {
                        let lines = gio::DataInputStream::new(&out);
                        while let Ok(Some(line)) = lines.read_line_utf8_future(glib::Priority::DEFAULT).await {
                            st.progress_from(&line);
                            said.push_str(&line);
                            said.push('\n');
                        }
                    }
                    let _ = p.wait_future().await;
                    if p.has_exited() { p.exit_status() } else { -1 }
                }
                Err(_) => -1,
            };
            let _ = pulse;
            st.finished(&a, &what, code, &said);
        });
    }

    fn progress_from(&self, line: &str) {
        static STEP: LazyLock<regex::Regex> = LazyLock::new(|| regex::Regex::new(r"\(\s*(\d+)/(\d+)\)").unwrap());
        static PERCENT: LazyLock<regex::Regex> = LazyLock::new(|| regex::Regex::new(r"(\d+)%").unwrap());
        let n = |c: &regex::Captures, i: usize| c[i].parse::<f64>().unwrap_or(0.0);
        if let Some(c) = STEP.captures(line) {
            let total = n(&c, 2);
            if total > 0.0 {
                self.progress.set((n(&c, 1) / total).clamp(0.0, 1.0));
            }
        } else if let Some(c) = PERCENT.captures(line) {
            self.progress.set((n(&c, 1) / 100.0).clamp(0.0, 1.0));
        } else {
            return;
        }
        self.update_rows();
    }

    fn finished(self: &Rc<Self>, a: &Value, what: &str, code: i32, said: &str) {
        self.busy.borrow_mut().clear();
        self.progress.set(-1.0);
        let name = s(a, "name");
        let has = |pattern: &str| regex::RegexBuilder::new(pattern).case_insensitive(true).build().is_ok_and(|r| r.is_match(said));
        if code == 0 {
            self.say(&if what == "install" { trf!("{0} is installed.", name) } else { trf!("{0} is removed.", name) }, false);
        } else if code == 126 || code == 127 {
            self.say(&tr("Cancelled."), false);
        } else if has("failed retrieving file|404|not found in sync db") {
            self.say(&tr("The package lists are out of date: update the system first (the update panel), then try again."), true);
        } else if has("breaks dependency|required by") {
            self.say(&trf!("{0} is needed by something else on the system, so it stays.", name), true);
        } else if has("unable to lock database") {
            self.say(&tr("Another update or install is running; try again when it's done."), true);
        } else {
            self.say(&trf!("That didn't work: {0}", said.trim().lines().last().unwrap_or("")), true);
        }
        if s(a, "source") == "aur" {
            let pkg = s(a, "pkg");
            for x in self.aur_results.borrow_mut().iter_mut().filter(|x| s(x, "pkg") == pkg) {
                x["installed"] = Value::Bool(what == "install" && code == 0);
            }
        }
        if code == 0 {
            for (_, parts) in self.rows.borrow_mut().iter_mut().filter(|(p, _)| p == s(a, "pkg")) {
                parts.installed = what == "install";
            }
        }
        self.update_rows();
        self.index(&["--installed-only"]);
        self.list_foreign();
    }

    fn watch_aur(self: &Rc<Self>, left: u32) {
        let st = self.clone();
        glib::timeout_add_local_once(Duration::from_secs(4), move || {
            let name = st.aur_waiting.borrow().clone();
            if name.is_empty() {
                return;
            }
            if left == 0 {
                st.aur_waiting.borrow_mut().clear();
                return;
            }
            let st2 = st.clone();
            glib::spawn_future_local(async move {
                let state = vyntaris_core::paths::runtime_dir().join("vyntaris-aur").join(&name);
                let (_, code) = output(&["pacman", "-Qq", &name]).await;
                let how = if code == 0 { "ok".to_string() } else { std::fs::read_to_string(state).unwrap_or_default().trim().to_string() };
                if how.is_empty() {
                    st2.watch_aur(left - 1);
                    return;
                }
                st2.aur_waiting.borrow_mut().clear();
                match how.as_str() {
                    "ok" => {
                        st2.say(&trf!("{0} is installed.", name), false);
                        for x in st2.aur_results.borrow_mut().iter_mut().filter(|x| s(x, "pkg") == name) {
                            x["installed"] = Value::Bool(true);
                        }
                        st2.list_foreign();
                    }
                    "cancelled" => st2.say(&tr("Cancelled."), false),
                    _ => st2.say(&trf!("{0} couldn't be built (its recipe may be out of date).", name), true),
                }
            });
        });
    }

    fn open(&self, a: &Value) {
        let id = s(a, "id");
        let id = if id.ends_with(".desktop") { id.to_string() } else { format!("{id}.desktop") };
        let name = s(a, "name").to_lowercase();
        let all = gio::AppInfo::all();
        let entry = all.iter().find(|i| i.id().is_some_and(|i| i == id))
            .or_else(|| all.iter().find(|i| i.display_name().to_lowercase() == name || i.name().to_lowercase() == name));
        let Some(entry) = entry.and_then(|e| e.id()) else { return };
        let entry = entry.to_string();
        let short = entry.trim_end_matches(".desktop");
        if LAUNCHERS.contains(&short) && vyntaris_ui::which("mangohud") {
            let logs = vyntaris_core::paths::runtime_dir().join("vyntaris-mangohud").display().to_string();
            let config = format!("MANGOHUD_CONFIG=no_display,output_folder={logs},log_interval=1000,autostart_log=1");
            vyntaris_ui::launch(&["sh", "-c", "mkdir -p \"$1\" && shift && exec \"$@\"", "sh", &logs, "env", "MANGOHUD=1", &config, "gtk4-launch", &entry]);
        } else {
            vyntaris_ui::launch(&["gtk4-launch", &entry]);
        }
        if let Some(w) = self.win.borrow().as_ref() {
            w.close();
        }
    }
}

fn build(app: &adw::Application) -> adw::ApplicationWindow {
    let st = Rc::new(Store {
        apps: RefCell::default(),
        aur: RefCell::default(),
        aur_on: Cell::new(vyntaris_core::settings::Settings::load().bool("apps.aur", false)),
        getting_helper: Cell::new(false),
        aur_results: RefCell::default(),
        aur_asked: Cell::new(0),
        foreign: RefCell::default(),
        section: RefCell::new("popular".into()),
        query: RefCell::default(),
        busy: RefCell::default(),
        busy_what: RefCell::default(),
        progress: Cell::new(-1.0),
        indexing: Cell::new(false),
        aur_waiting: RefCell::default(),
        rows: RefCell::default(),
        aur_delay: RefCell::default(),
        win: RefCell::default(),
        monitor: RefCell::default(),
        title: adw::WindowTitle::new(&tr("Store"), &tr("Arch")),
        sections: gtk::ListBox::builder().css_classes(["navigation-sidebar"]).build(),
        search: gtk::SearchEntry::builder().placeholder_text(tr("Search apps")).build(),
        heading: gtk::Label::builder().xalign(0.0).hexpand(true).css_classes(["title-2"]).build(),
        count: gtk::Label::builder().css_classes(["dim-label"]).build(),
        message: gtk::Label::builder().wrap(true).xalign(0.0).visible(false).css_classes(["card", "vyntaris-note"]).build(),
        list: gtk::ListBox::builder().selection_mode(gtk::SelectionMode::None).css_classes(["boxed-list"]).build(),
        aur_box: gtk::Box::builder().orientation(gtk::Orientation::Vertical).spacing(6).build(),
        aur_list: gtk::ListBox::builder().selection_mode(gtk::SelectionMode::None).css_classes(["boxed-list"]).build(),
        aur_offer: gtk::Box::builder().orientation(gtk::Orientation::Horizontal).spacing(12).margin_top(12).visible(false).build(),
        empty: gtk::Label::builder().css_classes(["dim-label"]).margin_top(48).build(),
    });
    st.load();

    for (_, label, icon) in SECTIONS {
        let row = gtk::Box::new(gtk::Orientation::Horizontal, 10);
        row.append(&gtk::Image::from_icon_name(icon));
        row.append(&gtk::Label::builder().label(tr(label)).xalign(0.0).build());
        st.sections.append(&gtk::ListBoxRow::builder().child(&row).build());
    }
    st.sections.select_row(st.sections.row_at_index(0).as_ref());
    let s2 = st.clone();
    st.sections.connect_row_activated(move |_, row| {
        let id = SECTIONS[row.index() as usize].0;
        *s2.section.borrow_mut() = id.to_string();
        if s2.search.text().is_empty() {
            s2.show();
        } else {
            s2.search.set_text("");
        }
    });
    let s2 = st.clone();
    st.search.connect_search_changed(move |_| s2.query_changed());
    let side = gtk::Box::builder().orientation(gtk::Orientation::Vertical).spacing(12)
        .margin_top(12).margin_bottom(12).margin_start(12).margin_end(12).build();
    side.append(&st.search);
    side.append(&gtk::ScrolledWindow::builder().vexpand(true).child(&st.sections).build());
    let side_bar = adw::ToolbarView::new();
    side_bar.add_top_bar(&adw::HeaderBar::builder().title_widget(&st.title).build());
    side_bar.set_content(Some(&side));

    let top = gtk::Box::new(gtk::Orientation::Horizontal, 12);
    top.append(&st.heading);
    top.append(&st.count);
    let aur_heading = gtk::Label::builder().label(tr("From the AUR")).xalign(0.0).css_classes(["heading", "warning"]).margin_top(12).build();
    let aur_note = gtk::Label::builder().label(tr("Recipes anyone can submit, built on this computer and installed like the rest."))
        .xalign(0.0).wrap(true).css_classes(["dim-label", "caption"]).build();
    st.aur_box.append(&aur_heading);
    st.aur_box.append(&aur_note);
    st.aur_box.append(&st.aur_list);
    let offer_note = gtk::Label::builder().label(tr("Not here? The AUR, recipes shared by Arch's users, may have it."))
        .xalign(0.0).wrap(true).hexpand(true).css_classes(["dim-label"]).build();
    let offer = gtk::Button::builder().label(tr("Search the AUR too…")).valign(gtk::Align::Center).build();
    let s2 = st.clone();
    offer.connect_clicked(move |_| s2.offer_aur());
    st.aur_offer.append(&offer_note);
    st.aur_offer.append(&offer);
    let page = gtk::Box::builder().orientation(gtk::Orientation::Vertical).spacing(12)
        .margin_top(18).margin_bottom(24).margin_start(18).margin_end(18).build();
    for w in [top.upcast_ref::<gtk::Widget>(), st.message.upcast_ref(), st.list.upcast_ref(), st.aur_box.upcast_ref(), st.aur_offer.upcast_ref(), st.empty.upcast_ref()] {
        page.append(w);
    }
    let scroll = gtk::ScrolledWindow::builder().hscrollbar_policy(gtk::PolicyType::Never).vexpand(true)
        .child(&adw::Clamp::builder().maximum_size(820).child(&page).build()).build();
    let content = adw::ToolbarView::new();
    content.add_top_bar(&adw::HeaderBar::builder().show_title(false).build());
    content.set_content(Some(&scroll));

    let split = adw::NavigationSplitView::builder()
        .sidebar(&adw::NavigationPage::builder().title(tr("Store")).child(&side_bar).build())
        .content(&adw::NavigationPage::builder().title(tr("Apps")).child(&content).build())
        .min_sidebar_width(232.0).max_sidebar_width(232.0).build();
    let win = adw::ApplicationWindow::builder().application(app).title(tr("Store")).default_width(880).default_height(660)
        .width_request(700).height_request(480).content(&split).build();
    vyntaris_ui::escape_closes(&win);
    *st.win.borrow_mut() = Some(win.clone());

    let file = gio::File::for_path(catalogue());
    if let Ok(monitor) = file.monitor_file(gio::FileMonitorFlags::NONE, gio::Cancellable::NONE) {
        let s2 = st.clone();
        monitor.connect_changed(move |_, _, _, event| {
            if matches!(event, gio::FileMonitorEvent::ChangesDoneHint | gio::FileMonitorEvent::Created) && !s2.indexing.get() {
                s2.load();
                s2.show();
            }
        });
        *st.monitor.borrow_mut() = Some(monitor);
    }

    let s2 = st.clone();
    glib::spawn_future_local(async move {
        let helper = ["yay", "paru"].into_iter().find(|h| vyntaris_ui::which(h)).unwrap_or("");
        *s2.aur.borrow_mut() = helper.to_string();
        s2.helper_shown();
        s2.show();
        s2.helper_if_missing();
    });
    st.show();
    STORE.with_borrow_mut(|s| *s = Some(st));
    win
}
