# Contributing

Thank you for wanting to help. Vyntaris is young, and the most useful thing right now is to use it and say
what goes wrong.

## Reporting

- **Something broken:** Dr. Help → **Report a problem** fills in an issue with what the system says, shown
  to you before anything is sent. Or open an issue and pick a form.
- **An idea:** an issue with the **An idea** form. Say what you want to do, not only the feature.
- **A security problem:** never in an issue, see [SECURITY.md](SECURITY.md).

## Changing the code

Pull requests are welcome. For anything bigger than a fix, open an issue first, so we agree on the way
before you spend the time.

- **Match what's there.** Read the code around your change and write like it. The repository has no
  comments in code: names and small functions say what it does, and the README says why.
- **Every text the user sees** goes through `Tr.t()` in QML or `tr()` / `trf!()` in Rust, written in
  English. Translations are in `config/quickshell/i18n/`; `tools/i18n.py` lists what a language lacks.
- **Test it.** `cd rust && cargo test`, the `tools/test-*.sh` and `tools/test-*.py` that touch your change,
  and for the desktop itself, `tools/vm-test.sh` or a real session. CI runs all of it on every pull request,
  except three that need a desktop and run only by hand: `tools/test-ui.sh` (the shell's panels, in a nested
  Hyprland), `tools/test-browser-popup.sh` (Firefox's popups) and `tools/test-install-layouts.sh` (installing
  next to other systems and over an earlier Vyntaris, in VMs). Run the one that touches your change.
- **Be decent.** Everyone here is under the [code of conduct](CODE_OF_CONDUCT.md).
- **One change per pull request,** with a title that says what it does.

## License

Vyntaris is under the GNU General Public License, version 3 or any later version ([LICENSE](LICENSE)). By
sending a pull request, you agree that your contribution is under the same license.
