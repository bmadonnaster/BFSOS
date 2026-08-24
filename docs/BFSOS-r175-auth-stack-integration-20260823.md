# BFSOS r175 authentication-stack integration — 2026-08-23

## Verified versions

Current BLFS/LFS development references were checked before changing the chain:

- CrackLib 2.10.3
- Linux-PAM 1.7.2
- libpwquality 1.4.5
- Shadow 4.20.2
- systemd 261.2

No version bump was required for those five packages in this pass.

## Base build order

The Bootstrap/base build order is now:

1. CrackLib
2. Linux-PAM
3. libpwquality
4. Shadow
5. systemd later in the normal base sequence

Both `bootstrap.sh` and `bootstrap-clean-start.sh` use this order.

`libpwquality` was moved from `ports/opt` to `ports/core` because it is now
part of the BFSOS base authentication policy rather than an optional add-on.

## CrackLib

- Hardened the recipe and dependency metadata.
- The English CrackLib word list is staged into the package.
- The port now creates `pw_dict.{hwm,pwd,pwi}` inside `$PKG/usr/lib/cracklib`
  during package creation instead of leaving a live-system post-install step.
- The package build verifies that the staged dictionary exists.
- The default dictionary path remains `/usr/lib/cracklib/pw_dict`.

## Linux-PAM and libpwquality

- The generic BFSOS `system-password` stack now runs `pam_pwquality.so` before
  `pam_unix.so`.
- `pam_unix.so` retains `yescrypt shadow try_first_pass`.
- `other` is now the restrictive BLFS-style `pam_warn` + `pam_deny` policy.
- libpwquality installs a conservative `/etc/security/pwquality.conf`:
  minlen=8, difok=1, minclass=1, dictionary checking enabled, username checking
  enabled, and enforcement enabled.
- The dictionary path is explicitly `/usr/lib/cracklib/pw_dict`.
- libpwquality's Python wheel is staged with pip `--root=$PKG` rather than
  relying on DESTDIR behavior that pip does not use as its primary staging
  interface.
- The recipe verifies that `/usr/lib/security/pam_pwquality.so` is present.

## Shadow

- Shadow explicitly depends on Linux-PAM/libpwquality/libxcrypt.
- Current BLFS configure policy is folded into the BFSOS recipe, including
  PAM, bcrypt/yescrypt and the current stdint compatibility fix.
- Shadow's upstream PAM configuration is suppressed with `pamddir=` during
  staged install so it cannot overwrite the BFSOS PAM policy.
- Shadow continues to own its service-specific PAM files (`login`, `passwd`,
  `su`, `chpasswd`, `newusers`, `chage`, user/group management services).
- `login.defs` functions now handled by PAM are commented out in the packaged
  configuration.

## systemd

- systemd remains after Shadow in the base sequence and is built with PAM
  enabled, so `pam_systemd.so`/systemd-logind integration is available only
  after PAM is present.
- The systemd recipe was made fail-fast in configure/build/install.

## Configuration ownership / upgrades

- Linux-PAM owns the generic `system-*` and `other` policy files.
- libpwquality owns `/etc/security/pwquality.conf`.
- Shadow owns its service-specific PAM files and `/etc/login.defs`.
- systemd owns `/etc/pam.d/systemd-user`.
- pkgadd policy explicitly preserves `/etc/pam.d/*`, `/etc/security/*`, and
  `/etc/login.defs` on upgrades. Fresh installs get BFSOS defaults; upgrades do
  not silently replace an administrator's working authentication policy.
- pkgutils release was bumped for this policy update.

## Installer integration

Installer r65 was created from r64 and the `install-bfs-menu-current.sh`
symlink now points to it.

The installer still uses Shadow's `chpasswd`, which routes password changes
through PAM in the PAM-enabled build. If libpwquality rejects a password, r65
now reports the rejection and lets the user try another password instead of
aborting the entire installation transaction. Blank password selection retains
the existing safe behavior: the account remains password-locked.

## Future-base validation helper

`scripts/bfs-auth-stack-check.sh` was added. It checks the installed versions,
CrackLib dictionary, setuid `unix_chkpwd`, `pam_pwquality.so`,
`system-password`, yescrypt, Shadow PAM service files and systemd-user PAM
integration without modifying any account password.

Runtime tests still required on the next fresh base:

- installer-created root and standard user passwords
- intentionally locked-password account
- weak password rejection and retry
- `login`
- `su`
- `passwd`
- root changing another user's password
- normal user changing their own password
- `chpasswd`
- SSH password authentication when enabled
- systemd-logind/session registration
- package reinstall/upgrade preservation behavior
