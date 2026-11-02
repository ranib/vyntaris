use std::io::{Read, Write};
use std::process::{Command, Stdio};

const USAGE: &str = "settings-admin user-add NAME \"FULL NAME\" admin|standard | user-remove NAME | user-admin NAME on|off \
                     | user-name NAME \"FULL NAME\" | locale LANGUAGE [FORMATS] \
                     | nvidia-start boot|demand";

#[derive(Debug, PartialEq)]
pub struct Refused(pub String);

fn no<T>(why: impl Into<String>) -> Result<T, Refused> {
    Err(Refused(why.into()))
}

pub trait System {
    fn run(&mut self, cmd: &[&str], stdin: Option<&str>) -> Result<(), Refused>;
    fn uid(&self, name: &str) -> Option<u32>;
    fn admins(&self) -> Vec<String>;
    fn caller(&self) -> String;
    fn read(&self, what: File) -> Option<String>;
    fn write(&mut self, what: File, text: &str) -> Result<(), Refused>;
    fn password(&mut self) -> String;
}

#[derive(Clone, Copy)]
pub enum File {
    LocaleGen,
    Supported,
    NvidiaStart,
}

pub fn is_name(s: &str) -> bool {
    let mut c = s.chars();
    matches!(c.next(), Some('a'..='z' | '_'))
        && s.len() <= 32
        && c.all(|c| matches!(c, 'a'..='z' | '0'..='9' | '_' | '-'))
}

fn person(sys: &dyn System, name: &str) -> Result<(), Refused> {
    if !is_name(name) {
        return no(format!("not a user name: {name}"));
    }
    match sys.uid(name) {
        None => no(format!("no user {name}")),
        Some(uid) if !(1000..60000).contains(&uid) => no(format!("{name} is the system's, not a person's")),
        Some(_) => Ok(()),
    }
}

pub fn full_name(text: &str) -> Result<String, Refused> {
    let t = text.trim();
    if t.is_empty() || t.chars().count() > 64 || t.contains([':', ',', '\n', '\r', '\0']) {
        return no("a name without : , or line breaks, up to 64 letters");
    }
    Ok(t.to_string())
}

fn password(sys: &mut dyn System) -> Result<String, Refused> {
    let pw = sys.password();
    let pw = pw.strip_suffix('\n').unwrap_or(&pw).to_string();
    if pw.chars().count() < 4 || pw.contains(['\n', ':']) {
        return no("a password of 4 or more characters, without : or line breaks");
    }
    Ok(pw)
}

fn last_admin(sys: &dyn System, name: &str) -> bool {
    let a = sys.admins();
    a.iter().any(|x| x == name) && a.len() == 1
}

pub fn user_add(sys: &mut dyn System, name: &str, full: &str, kind: &str) -> Result<(), Refused> {
    if !is_name(name) {
        return no(format!("not a user name: {name} (small letters, digits, - and _)"));
    }
    if sys.uid(name).is_some() {
        return no(format!("there is a user {name} already"));
    }
    if kind != "admin" && kind != "standard" {
        return no("admin or standard");
    }
    let full = full_name(full)?;
    let pw = password(sys)?;
    let mut cmd = vec!["useradd", "-m", "-s", "/usr/bin/zsh", "-c", &full];
    if kind == "admin" {
        cmd.extend(["-G", "wheel"]);
    }
    cmd.push(name);
    sys.run(&cmd, None)?;
    sys.run(&["chpasswd"], Some(&format!("{name}:{pw}\n")))
}

pub fn user_remove(sys: &mut dyn System, name: &str) -> Result<(), Refused> {
    person(sys, name)?;
    if name == sys.caller() {
        return no("you can't remove yourself");
    }
    if last_admin(sys, name) {
        return no("the last administrator stays");
    }
    sys.run(&["userdel", name], None)
}

pub fn user_admin(sys: &mut dyn System, name: &str, on: bool) -> Result<(), Refused> {
    person(sys, name)?;
    if on {
        return sys.run(&["gpasswd", "-a", name, "wheel"], None);
    }
    if name == sys.caller() {
        return no("you can't take your own administrator rights");
    }
    if last_admin(sys, name) {
        return no("the last administrator stays one");
    }
    sys.run(&["gpasswd", "-d", name, "wheel"], None)
}

pub fn user_name(sys: &mut dyn System, name: &str, full: &str) -> Result<(), Refused> {
    person(sys, name)?;
    let full = full_name(full)?;
    sys.run(&["usermod", "-c", &full, name], None)?;
    let _ = sys.run(&["systemctl", "start", "--no-block", &format!("vyntaris-greeter-sync@{name}.service")], None);
    Ok(())
}

pub fn locale_entry(sys: &dyn System, locale: &str) -> Result<(String, String), Refused> {
    let (base, modifier) = match locale.split_once('@') {
        Some((b, m)) => (b, format!("@{m}")),
        None => (locale, String::new()),
    };
    let good_base = base.split_once('_').is_some_and(|(l, c)| {
        (2..=3).contains(&l.len()) && l.chars().all(|c| c.is_ascii_lowercase()) && c.len() == 2 && c.chars().all(|c| c.is_ascii_uppercase())
    });
    let good_mod = modifier.is_empty() || (modifier.len() > 1 && modifier[1..].chars().all(|c| c.is_ascii_lowercase()));
    if !good_base || !good_mod {
        return no(format!("not a locale: {locale}"));
    }
    let Some(supported) = sys.read(File::Supported) else { return no("no list of locales") };
    let lines: Vec<&str> = supported.lines().map(str::trim).collect();
    for (entry, name) in [
        (format!("{base}.UTF-8{modifier} UTF-8"), format!("{base}.UTF-8{modifier}")),
        (format!("{base}{modifier} UTF-8"), format!("{base}{modifier}")),
    ] {
        if lines.contains(&entry.as_str()) {
            return Ok((entry, name));
        }
    }
    no(format!("{locale} isn't one this system knows in UTF-8"))
}

pub fn make_locale(sys: &mut dyn System, entry: &str) -> Result<bool, Refused> {
    let text = sys.read(File::LocaleGen).unwrap_or_default();
    let mut lines: Vec<String> = text.lines().map(str::to_string).collect();
    if lines.iter().any(|l| l.trim() == entry) {
        return Ok(false);
    }
    match lines.iter().position(|l| l.trim_start_matches('#').trim() == entry) {
        Some(i) => lines[i] = entry.to_string(),
        None => lines.push(entry.to_string()),
    }
    sys.write(File::LocaleGen, &(lines.join("\n") + "\n"))?;
    Ok(true)
}

pub fn set_locale(sys: &mut dyn System, language: &str, formats: Option<&str>) -> Result<(), Refused> {
    let lang = locale_entry(sys, language)?;
    let form = match formats {
        Some(f) => locale_entry(sys, f)?,
        None => lang.clone(),
    };
    let a = make_locale(sys, &lang.0)?;
    let b = make_locale(sys, &form.0)?;
    if a || b {
        sys.run(&["locale-gen"], None)?;
    }
    let mut values = vec![format!("LANG={}", lang.1)];
    if form != lang {
        values.extend(["LC_TIME", "LC_NUMERIC", "LC_MONETARY", "LC_PAPER", "LC_MEASUREMENT"].iter().map(|k| format!("{k}={}", form.1)));
    }
    let mut cmd = vec!["localectl", "set-locale"];
    cmd.extend(values.iter().map(String::as_str));
    sys.run(&cmd, None)
}

pub fn nvidia_start(sys: &mut dyn System, at_boot: bool) -> Result<(), Refused> {
    sys.write(File::NvidiaStart, if at_boot { "" } else { "blacklist nvidia\n" })
}

pub fn dispatch(sys: &mut dyn System, a: &[&str]) -> Result<(), Option<Refused>> {
    match a {
        ["user-add", name, full, kind] => user_add(sys, name, full, kind),
        ["user-remove", name] => user_remove(sys, name),
        ["user-admin", name, "on"] => user_admin(sys, name, true),
        ["user-admin", name, "off"] => user_admin(sys, name, false),
        ["user-name", name, full] => user_name(sys, name, full),
        ["locale", lang] => set_locale(sys, lang, None),
        ["locale", lang, form] => set_locale(sys, lang, Some(form)),
        ["nvidia-start", "boot"] => nvidia_start(sys, true),
        ["nvidia-start", "demand"] => nvidia_start(sys, false),
        _ => return Err(None),
    }
    .map_err(Some)
}

struct Real;

const NVIDIA_START: &str = "/etc/modprobe.d/vyntaris-nvidia-on-demand.conf";

fn group_members(group: &str) -> Vec<String> {
    std::fs::read_to_string("/etc/group")
        .unwrap_or_default()
        .lines()
        .find(|l| l.split(':').next() == Some(group))
        .and_then(|l| l.split(':').nth(3))
        .map(|m| m.split(',').filter(|s| !s.is_empty()).map(str::to_string).collect())
        .unwrap_or_default()
}

impl System for Real {
    fn run(&mut self, cmd: &[&str], stdin: Option<&str>) -> Result<(), Refused> {
        let mut child = Command::new(cmd[0])
            .args(&cmd[1..])
            .stdin(if stdin.is_some() { Stdio::piped() } else { Stdio::null() })
            .stdout(Stdio::null())
            .stderr(Stdio::piped())
            .spawn()
            .map_err(|e| Refused(format!("{}: {e}", cmd[0])))?;
        if let (Some(text), Some(mut pipe)) = (stdin, child.stdin.take()) {
            let _ = pipe.write_all(text.as_bytes());
        }
        let out = child.wait_with_output().map_err(|e| Refused(e.to_string()))?;
        if out.status.success() {
            return Ok(());
        }
        let err = String::from_utf8_lossy(&out.stderr).trim().to_string();
        no(if err.is_empty() { format!("{} failed", cmd[0]) } else { err })
    }
    fn uid(&self, name: &str) -> Option<u32> {
        let c = std::ffi::CString::new(name).ok()?;
        let p = unsafe { libc::getpwnam(c.as_ptr()) };
        (!p.is_null()).then(|| unsafe { (*p).pw_uid })
    }
    fn admins(&self) -> Vec<String> {
        group_members("wheel")
    }
    fn caller(&self) -> String {
        let Some(uid) = std::env::var("PKEXEC_UID").ok().and_then(|u| u.parse::<u32>().ok()) else { return String::new() };
        let p = unsafe { libc::getpwuid(uid) };
        if p.is_null() {
            return String::new();
        }
        unsafe { std::ffi::CStr::from_ptr((*p).pw_name) }.to_string_lossy().to_string()
    }
    fn read(&self, what: File) -> Option<String> {
        std::fs::read_to_string(match what {
            File::LocaleGen => "/etc/locale.gen",
            File::Supported => "/usr/share/i18n/SUPPORTED",
            File::NvidiaStart => NVIDIA_START,
        })
        .ok()
    }
    fn write(&mut self, what: File, text: &str) -> Result<(), Refused> {
        let path = match what {
            File::LocaleGen => "/etc/locale.gen",
            File::NvidiaStart => {
                let _ = std::fs::create_dir_all("/etc/modprobe.d");
                NVIDIA_START
            }
            File::Supported => return no("SUPPORTED isn't written"),
        };
        std::fs::write(path, text).map_err(|e| Refused(e.to_string()))
    }
    fn password(&mut self) -> String {
        let mut s = String::new();
        let _ = std::io::stdin().read_to_string(&mut s);
        s
    }
}

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let a: Vec<&str> = args.iter().map(String::as_str).collect();
    if unsafe { libc::geteuid() } != 0 {
        eprintln!("this needs root");
        std::process::exit(1);
    }
    match dispatch(&mut Real, &a) {
        Ok(()) => {}
        Err(Some(Refused(why))) => {
            eprintln!("{why}");
            std::process::exit(1);
        }
        Err(None) => {
            eprintln!("{USAGE}");
            std::process::exit(2);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[derive(Default)]
    struct Fake {
        ran: Vec<(Vec<String>, Option<String>)>,
        users: Vec<(&'static str, u32)>,
        admins: Vec<String>,
        caller: String,
        locale_gen: String,
        nvidia: String,
        stdin: String,
    }

    impl System for Fake {
        fn run(&mut self, cmd: &[&str], stdin: Option<&str>) -> Result<(), Refused> {
            self.ran.push((cmd.iter().map(|s| s.to_string()).collect(), stdin.map(str::to_string)));
            Ok(())
        }
        fn uid(&self, name: &str) -> Option<u32> {
            self.users.iter().find(|(n, _)| *n == name).map(|(_, u)| *u)
        }
        fn admins(&self) -> Vec<String> {
            self.admins.clone()
        }
        fn caller(&self) -> String {
            self.caller.clone()
        }
        fn read(&self, what: File) -> Option<String> {
            Some(match what {
                File::Supported => "en_US.UTF-8 UTF-8\nen_US ISO-8859-1\nsr_RS UTF-8\nsr_RS@latin UTF-8\nde_DE.UTF-8 UTF-8\n".into(),
                File::LocaleGen => self.locale_gen.clone(),
                File::NvidiaStart => self.nvidia.clone(),
            })
        }
        fn write(&mut self, what: File, text: &str) -> Result<(), Refused> {
            match what {
                File::NvidiaStart => self.nvidia = text.into(),
                _ => self.locale_gen = text.into(),
            }
            Ok(())
        }
        fn password(&mut self) -> String {
            std::mem::take(&mut self.stdin)
        }
    }

    fn people() -> Fake {
        Fake {
            users: vec![("root", 0), ("ana", 1000), ("bob", 1001), ("eve", 1002)],
            admins: vec!["ana".into(), "bob".into()],
            caller: "ana".into(),
            ..Default::default()
        }
    }

    #[test]
    fn locales() {
        let mut f = Fake::default();
        assert_eq!(locale_entry(&f, "en_US"), Ok(("en_US.UTF-8 UTF-8".into(), "en_US.UTF-8".into())));
        assert_eq!(locale_entry(&f, "sr_RS@latin"), Ok(("sr_RS@latin UTF-8".into(), "sr_RS@latin".into())));
        assert_eq!(locale_entry(&f, "sr_RS"), Ok(("sr_RS UTF-8".into(), "sr_RS".into())));
        assert!(locale_entry(&f, "xx_XX").is_err());
        assert!(locale_entry(&f, "en_US; rm -rf /").is_err());

        f.locale_gen = "#en_US.UTF-8 UTF-8  \n#  de_DE.UTF-8 UTF-8\n#sr_RS@latin UTF-8\n".into();
        assert_eq!(make_locale(&mut f, "de_DE.UTF-8 UTF-8"), Ok(true));
        assert!(f.locale_gen.contains("\nde_DE.UTF-8 UTF-8\n"), "turned on in its own line");
        assert_eq!(make_locale(&mut f, "de_DE.UTF-8 UTF-8"), Ok(false), "once: not again");
        assert_eq!(make_locale(&mut f, "sr_RS UTF-8"), Ok(true));
        assert!(f.locale_gen.ends_with("sr_RS UTF-8\n"), "one not listed is added");

        f.ran.clear();
        set_locale(&mut f, "sr_RS@latin", None).unwrap();
        let names: Vec<&str> = f.ran.iter().map(|(c, _)| c[0].as_str()).collect();
        assert_eq!(names, ["locale-gen", "localectl"]);
        assert_eq!(f.ran[1].0, ["localectl", "set-locale", "LANG=sr_RS@latin"]);
        f.ran.clear();
        set_locale(&mut f, "sr_RS@latin", Some("de_DE")).unwrap();
        let last = &f.ran.last().unwrap().0;
        assert_eq!(&last[..4], ["localectl", "set-locale", "LANG=sr_RS@latin", "LC_TIME=de_DE.UTF-8"]);
        assert_eq!(last.len(), 8);
        assert!(!f.ran.iter().any(|(c, _)| c[0] == "locale-gen"), "nothing to make: no locale-gen");
    }

    #[test]
    fn names_and_passwords() {
        assert!(full_name("Ana:Marić").is_err());
        assert!(full_name("Ana\nroot").is_err());
        assert_eq!(full_name("  Ana Marić "), Ok("Ana Marić".into()));
        let mut f = people();
        f.stdin = "abc\n".into();
        assert!(user_add(&mut f, "zed", "Zed", "standard").is_err(), "a password under 4");
        assert!(user_add(&mut f, "Root!", "X", "admin").is_err());
        assert!(person(&f, "root").is_err(), "root is the system's");
        f.stdin = "secret\n".into();
        user_add(&mut f, "zoe", "Zoe", "admin").unwrap();
        assert_eq!(f.ran[f.ran.len() - 2].0, ["useradd", "-m", "-s", "/usr/bin/zsh", "-c", "Zoe", "-G", "wheel", "zoe"]);
        assert!(user_add(&mut f, "ana", "Ana", "admin").is_err(), "one there is already");
    }

    #[test]
    fn nobody_locked_out() {
        let mut f = people();
        assert!(user_admin(&mut f, "ana", false).is_err(), "your own rights");
        assert!(user_remove(&mut f, "ana").is_err(), "yourself");
        user_admin(&mut f, "bob", false).unwrap();
        assert_eq!(f.ran.last().unwrap().0, ["gpasswd", "-d", "bob", "wheel"]);
        f.admins = vec!["bob".into()];
        f.caller = "eve".into();
        assert!(user_admin(&mut f, "bob", false).is_err(), "the last administrator stays one");
        assert!(user_remove(&mut f, "bob").is_err(), "the last administrator isn't removed");
        user_admin(&mut f, "eve", true).unwrap();
        assert_eq!(f.ran.last().unwrap().0, ["gpasswd", "-a", "eve", "wheel"]);
        assert_eq!(dispatch(&mut f, &["user-admin", "eve", "maybe"]), Err(None));
    }

    #[test]
    fn nvidia_at_start_or_on_demand() {
        let mut f = Fake::default();
        dispatch(&mut f, &["nvidia-start", "demand"]).unwrap();
        assert_eq!(f.nvidia, "blacklist nvidia\n");
        dispatch(&mut f, &["nvidia-start", "boot"]).unwrap();
        assert_eq!(f.nvidia, "");
        assert_eq!(dispatch(&mut f, &["nvidia-start", "never"]), Err(None));
    }
}
