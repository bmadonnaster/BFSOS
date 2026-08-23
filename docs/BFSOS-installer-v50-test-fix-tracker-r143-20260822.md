# BFSOS Installer v50 Test / Fix Tracker

## r121 implementation pass --- MD boot persistence + serial console + Git-backed BFSOS ports --- 2026-08-22

-   **Installer r57 created:**
    `scripts/install-bfs-menu-v50-r57-git-md-boot-fixes.sh`;
    `scripts/install-bfs-menu-current.sh` now points to r57.
-   [x] **MD Linear/JBOD GRUB discovery fix implemented / fresh-install
    runtime regression pending:** required-MD discovery now recognizes
    Linux `lsblk` type `md` as well as `raid*`. This closes the exact
    static defect that caused the six-member Linear/JBOD array to be
    omitted from topology-derived `rd.md.uuid=` generation. MD UUID
    arguments remain stable-identity based and deduplicated.
-   [x] **Required `/etc/mdadm.conf` generation implemented / runtime
    regression pending:** r57 generates the installed target
    configuration only from MD UUIDs that are ancestors of the selected
    BFSOS filesystem topology. It filters `mdadm --detail --scan`
    against that required UUID set, avoids unrelated live-environment
    arrays, deduplicates output, and fails finalization if a required
    array cannot be represented.
-   [x] **Initramfs MD persistence verification strengthened:** when MD
    is required, final initramfs validation now requires the Dracut
    `mdraid` module, required RAID kernel drivers, and embedded
    `etc/mdadm.conf`. GRUB `rd.md.uuid=` generation and `mdadm.conf`
    generation use the same required-topology discovery path.
-   [x] **Optional serial troubleshooting console implemented / runtime
    regression pending:** System Settings and Installer Settings now
    expose a persisted `SERIAL_CONSOLE` toggle, default `no`. When
    enabled it adds `console=ttyS0,115200 console=tty0`;
    disabling/remaking GRUB strips only the installer-managed serial
    tokens so repeated changes are idempotent. Final review shows the
    setting.
-   [x] **BFSOS-owned ports migrated from HttpUp configuration to one
    Git-backed monorepo definition / network regression pending:** the
    corrected single-branch architecture from r108 is used.
    `/etc/ports/bfsos.git` points at
    `https://codeberg.org/bmadonnaster/BFSOS.git`, branch `main`, and
    maps all ten BFSOS collection directories from one repository
    checkout.
-   [x] **No ten-clone duplication:** the BFSOS extension to the CRUX
    Git driver adds an optional `COLLECTIONS=` monorepo mode. One cached
    checkout under `/var/cache/ports-git/bfsos` services `compat-32`,
    `compiz`, `contrib`, `core`, `gnome`, `lxqt`, `opt`, `plasma`,
    `xfce`, and `xorg`. Ordinary third-party `.git` definitions still
    use the stock single-collection behavior.
-   [x] **Git ports update safety implemented:** a complete remote
    snapshot is fetched/exported before `/usr/ports` is changed; first
    migration moves existing HttpUp trees into a timestamped backup;
    subsequent syncs store manifests and refuse to overwrite detected
    local edits. A failed fetch/export leaves the current ports trees
    unchanged. Local functional tests passed for first migration,
    repeated sync, and local-modification refusal.
-   [x] **Existing-base compatibility implemented --- no new base build
    required for the next install:** Git is removed from the
    optional-package selector. Before the first Git-backed `ports -u`,
    r57 checks for `git`; if absent it seeds the current `ports/opt/git`
    into the extracted old base and runs `prt-get depinst git`, then
    installs the updated Git driver and BFSOS Git config. This allows
    the current saved base archive to be used for the next clean
    install.
-   [x] **Future base policy implemented:** `git` is added to the
    Bootstrap base package list so future archives contain Git from the
    outset. Git port release is bumped to 3 because the installed ports
    driver changed; `prt-get` release is bumped to 3 and now ships
    `bfsos.git` instead of BFSOS `.httpup` definitions.
-   [x] **BFSOS HttpUp maintenance retired:** BFSOS-owned `.httpup`
    collection definitions and generated collection `REPO` manifests
    were removed from the source tree. `bfs-sync-ports.sh`,
    `bfs-update-ports.sh`, and `git-update-bfsos.sh` no longer
    regenerate HttpUp metadata. Generic HttpUp driver support remains
    available for third-party collections.
-   \[\~\] **r117 pkgmk mirror fallback audit:** current CRUX pkgmk
    already defines `PKGMK_SOURCE_MIRRORS` as ordered flat distfile
    fallbacks before the Pkgfile source, and BFSOS `/etc/pkgmk.conf`
    already exposes that array with bounded curl timeout/retry/stall
    handling. No default public BFSOS mirror was invented in this pass;
    runtime failover testing with real mirror endpoints remains pending.
-   [x] **Previously open duplicate tracker items statically
    reconciled:** current r57 retains successful-install
    `clear_resume_state`, human-readable package timing, Install/Retry
    labeling, checkpoint recovery ordering/dedup, and ownership-aware
    failure/success storage cleanup from r49-r56. Their remaining
    tracker work is runtime regression, not missing implementation.
-   **Static validation:** `bash -n` passes for Bootstrap, r57, and
    updated maintainer helpers; `sh -n` passes for the Git driver. The
    Git monorepo driver was functionally exercised against a local
    two-collection repository: initial migration passed, a second sync
    passed, and a deliberate local edit was refused with status 5
    without being overwritten.
-   **Next install regression target using the existing base archive:**
    fresh install -\> automatic pre-sync Git bootstrap if needed -\>
    single-fetch Git `ports -u` -\> sysup -\> layered MD/LUKS/LVM
    install -\> verify target `/etc/mdadm.conf` -\> verify GRUB
    `rd.md.uuid=` -\> verify `lsinitrd` contains mdadm
    configuration/modules -\> cold boot with no manual Dracut recovery.
    Also test the serial-console toggle both disabled and enabled.

## r119 Linear/JBOD installed-system boot regression --- missing Dracut MD kernel argument --- 2026-08-22

-   [x] **RUNTIME ROOT CAUSE CONFIRMED / MANUAL FIX BOOT-TESTED: a
    completed six-member Linear/JBOD -\> LUKS -\> multi-PV LVM
    installation initially dropped to the Dracut emergency shell because
    the installed GRUB kernel command line did not identify the required
    MD array.**
    -   Storage topology under test: six-member MD Linear/JBOD array -\>
        LUKS mapping `cryptraid`, plus a second LUKS mapping
        `cryptroot`; both mappings are LVM PVs in `bfs-vg`; the VG
        provides `root`, `usr`, `opt`, `home`, and `var`.
    -   Initial Dracut failure repeatedly scanned for Btrfs and then
        reported `/dev/bfs-vg/home`, `/dev/bfs-vg/opt`,
        `/dev/bfs-vg/root`, and the other dependent LVs unavailable
        because the MD-backed PV had never appeared.
    -   `/proc/mdstat` showed no assembled array at the failure point
        even though `mdadm`, `cryptsetup`, `lvm`, and `dmsetup` were
        present in the initramfs. `mdadm --examine --scan` correctly
        discovered the saved array UUID
        `c5b01545:77f84a08:8e4fe134:fda98654`.
    -   `lsinitrd` confirmed the Dracut `mdraid` module and required
        RAID kernel modules were present. The failure was therefore not
        a missing `mdadm` binary, missing RAID kernel driver, or omitted
        Dracut mdraid module.
    -   Manual recovery proved the storage stack itself was healthy:
        `mdadm --assemble --scan` assembled all six members,
        `cryptsetup luksOpen` opened the MD-backed LUKS container,
        `lvm vgchange -ay bfs-vg` activated all five LVs, and exiting
        the Dracut shell continued directly into a successful BFSOS
        boot.
    -   **Confirmed boot root cause:** the generated installed-system
        kernel command line contained the required `rd.luks.uuid=` and
        `rd.lvm.lv=` arguments but no `rd.md.uuid=` argument. Dracut's
        mdraid startup therefore had no explicit saved-array identity to
        assemble for this host-only boot path.
    -   Manual persistent test fix added
        `rd.md.uuid=c5b01545:77f84a08:8e4fe134:fda98654` to
        `/etc/default/grub`, regenerated `/boot/grub/grub.cfg`, and
        verified the argument appeared on the normal Linux 7.1.8 boot
        entries.
    -   **Cold reboot PASSED:** after regenerating GRUB with the MD UUID
        argument, the machine booted normally without manual `mdadm`,
        `cryptsetup`, or LVM commands in the Dracut shell.
-   [x] **IMPLEMENTED in installer r57 / fresh-install runtime
    regression pending:** topology-derived boot configuration must emit
    the required Dracut MD activation argument for every MD array that
    participates in the installed root/storage dependency graph.
    -   Prefer stable MD identity, not `/dev/md0`/`/dev/md127` pathname.
        Generate `rd.md.uuid=<MD UUID>` from the installed topology for
        each required array.
    -   Preserve all existing topology-derived `rd.luks.uuid=`,
        `rd.lvm.lv=`, root device, `rootflags=`, console, and other
        kernel arguments; adding MD activation must be additive and
        idempotent.
    -   Write the persistent value through `/etc/default/grub` so later
        `grub-mkconfig` runs and kernel upgrades retain the correct MD
        activation arguments.
    -   Support every installer MD level through the same topology
        logic: Linear/JBOD, RAID0, RAID1, RAID4, RAID5, RAID6, and
        RAID10. Do not special-case only Linear.
    -   Deduplicate MD UUID arguments when an array backs more than one
        downstream mapping/PV/LV.
    -   When the installer builds the initramfs, verify the required
        Dracut mdraid module/tools are included whenever the boot
        topology depends on MD; the current failing image did contain
        them, but this remains a useful final-validator check.
    -   **Regression matrix:** (1) Linear/JBOD -\> LUKS -\> LVM cold
        boot; (2) MD -\> LUKS without LVM where supported; (3) MD -\>
        LVM without LUKS where supported; (4) multi-PV VG spanning
        MD-backed and non-MD-backed LUKS PVs; (5) repeat `grub-mkconfig`
        and verify no duplicate `rd.md.uuid=` values; (6) verify
        array-node renumbering such as `md0` -\> `md127` does not affect
        boot because UUID identity is used.
    -   **Release criterion:** a fresh installer-generated configuration
        must cold boot the full layered topology without any manual
        Dracut-shell `mdadm --assemble --scan`, `cryptsetup luksOpen`,
        or `vgchange` recovery commands.
-   [x] **IMPLEMENTED in installer r57 / fresh-install runtime
    regression pending: generate and install a correct `/etc/mdadm.conf`
    for installer-created MD arrays, including Linear/JBOD.**
    -   The completed Linear/JBOD test installation did not have the
        required installed-system MD array definition in
        `/etc/mdadm.conf`; this is separate from the missing
        `rd.md.uuid=` GRUB argument.
    -   Generate the installed target's MD configuration from the arrays
        actually created/adopted for that installation rather than
        assuming only RAID levels reported as `raid*` require
        persistence. Linux MD Linear/JBOD must be included.
    -   Persist each required array using stable MD metadata/UUID
        identity so boot does not depend on a transient device node such
        as `/dev/md0` versus `/dev/md127`.
    -   Ensure `/etc/mdadm.conf` is written inside the target system
        before initramfs generation and that the generated initramfs
        receives the same required array configuration where Dracut's
        host-only boot path needs it.
    -   Do not copy unrelated arrays from the live environment into the
        installed target. Limit generated entries to arrays belonging to
        the selected/installed BFSOS storage topology.
    -   Make regeneration idempotent: rerunning
        installation/finalization must update or replace BFSOS-managed
        array entries without creating duplicate `ARRAY` records.
    -   Keep `mdadm.conf` generation and GRUB `rd.md.uuid=` generation
        derived from the same authoritative installer MD topology so the
        two boot mechanisms cannot drift.
    -   **Validation:** after installation, verify `/etc/mdadm.conf`
        contains the expected Linear/JBOD array UUID,
        `mdadm --examine --scan` agrees with the recorded identity,
        `lsinitrd` shows the required MD configuration/module content,
        and `/boot/grub/grub.cfg` contains the matching `rd.md.uuid=`.
    -   **Regression matrix:** repeat this validation for Linear/JBOD,
        RAID0, RAID1, RAID4, RAID5, RAID6, and RAID10 as those runtime
        layout tests are completed.
    -   **Release criterion:** no installer-created MD-dependent BFSOS
        installation may require the user to manually create
        `/etc/mdadm.conf` or manually add an MD UUID to GRUB in order to
        cold boot.

## r118 GRUB serial-console troubleshooting option --- 2026-08-22

-   [x] **IMPLEMENTED in installer r57 / runtime regression pending ---
    INSTALLER GRUB OPTION: expose an optional serial console for
    troubleshooting early boot and Dracut failures.**
    -   Add a user-selectable GRUB/kernel-console option in the
        installer rather than requiring a manual one-boot edit at the
        GRUB menu.
    -   Confirmed required QEMU/libvirt-friendly ordering:
        `console=ttyS0,115200 console=tty0`. Keep `console=tty0` last so
        the graphical/local console remains the preferred interactive
        console while serial output remains available.
    -   The option should be **disabled by default** for normal installs
        and clearly labeled as a troubleshooting/debugging aid.
    -   Persist the selection in the installer configuration/resume
        state and include it in the final review so the user can see
        whether serial-console output will be enabled.
    -   Merge the serial-console arguments with the topology-derived
        `GRUB_CMDLINE_LINUX` storage arguments; do not replace or
        suppress required `rd.luks.uuid=`, `rd.md.uuid=`/MD activation,
        `rd.lvm.lv=`, root, or rootflags settings.
    -   Avoid duplicate console arguments when regenerating
        `/etc/default/grub` or rerunning `grub-mkconfig`;
        enabling/disabling the option repeatedly must be idempotent.
    -   For VM troubleshooting, document that a libvirt serial
        PTY/console device must exist; with one present,
        `virsh console <domain>` can then provide a copy/paste-capable
        Dracut emergency shell without requiring networking in the
        initramfs.
    -   **Regression test:** install once with the option disabled and
        verify normal graphical boot is unchanged; enable it and verify
        both the graphical console and `virsh console` receive
        kernel/Dracut output, including a deliberately triggered Dracut
        emergency shell; disable it again and verify the serial
        arguments are removed cleanly.

## r117 pkgmk source-mirror fallback support --- 2026-08-20

-   \[\~\] **CONFIG SUPPORT CONFIRMED / runtime failover test pending
    --- PKGMK: configurable alternate/fallback source URLs for package
    downloads.**
    -   Motivated by highly variable download performance for the \~600
        MiB `linux-firmware` source archive; a single upstream endpoint
        can become a major bootstrap/install bottleneck.
    -   Preserve the Pkgfile's canonical upstream `source=` URL as the
        authoritative final fallback.
    -   Use/support `PKGMK_SOURCE_MIRRORS` in `/etc/pkgmk.conf` for an
        ordered list of alternate source locations before falling back
        to the Pkgfile URL. CRUX documents that multiple mirror URLs may
        be supplied in this array.
    -   Audit BFSOS `pkgmk` behavior to ensure failed/slow mirror
        attempts fall through cleanly without corrupting or accepting
        partial source archives.
    -   Keep the existing source cache behavior: if the correct source
        archive is already present in `PKGMK_SOURCE_DIR` / BFSOS source
        cache, do not download it again.
    -   Consider sensible connection/transfer timeout and retry handling
        so an unreachable or extremely slow mirror does not stall a
        build indefinitely before fallback.
    -   Do **not** solve this by adding duplicate equivalent URLs to a
        Pkgfile `source=(...)` array; those entries represent multiple
        required build sources, not alternate copies of one source.
    -   Initial regression target: `linux-firmware`. Configure at least
        two trustworthy mirrors/endpoints, deliberately make the first
        unavailable, and verify pkgmk automatically obtains the same
        expected archive from the next source and continues the build.
    -   After proving the mechanism, decide whether BFSOS should ship a
        small default global mirror list or leave mirror selection
        entirely to `/etc/pkgmk.conf`.

## r116 Linear/JBOD cold-recovery topology persistence fix --- 2026-08-20

-   [x] **FIX IMPLEMENTED in installer r56 / layered Linear/JBOD
    topology subsequently reached a completed install; dedicated
    cold-relaunch/profile regression remains to be closed
    independently.**
    -   Live relaunch testing showed recovery skipped the six-member
        Linear/JBOD array and only reopened one LUKS mapping.
    -   **Root cause:** `capture_recovery_storage_topology()` recognized
        only `lsblk` ancestor types matching `raid*`. Linux reports an
        MD Linear/JBOD ancestor as type `md`, so `/dev/md0` could be
        omitted from `RECOVERY_MD` persistence.
    -   **Additional robustness issue:** recovery topology was inferred
        primarily by walking selected leaf devices. With a multi-PV VG,
        an individual LV does not necessarily allocate extents from
        every PV, so a valid MD -\> LUKS -\> PV branch could also be
        omitted even when that branch is part of the configured VG.
    -   Installer r56 recognizes both `md` and `raid*` ancestor types.
    -   Installer r56 additionally persists every installer-created MD
        array, every installer-opened LUKS mapping (including its actual
        backing device), and every installer-activated VG, deduplicating
        these against ancestry-derived recovery state.
    -   Recovery order remains strict: **MD -\> LUKS -\> LVM -\>
        filesystems/Btrfs**.
    -   For an older/incomplete resume profile that references a missing
        `/dev/mdX` LUKS backing device but contains no saved MD
        topology, r56 now stops with an explicit non-destructive
        diagnostic instead of silently skipping MD and proceeding with
        only the recoverable LUKS mapping.
    -   Static validation: `bash -n` passes for installer r56.
    -   **Runtime regression:** create Linear/JBOD from six members -\>
        create LUKS on `/dev/md0` plus a second LUKS container -\> use
        both as PVs in one VG -\> save/fail -\> fully deactivate or cold
        reboot -\> relaunch r56 -\> verify MD is assembled/adopted
        first, both LUKS passphrases are requested/opened, VG/LVs
        activate, and the exact filesystem/Btrfs plan mounts.
    -   **Profile verification:** after the next configured run, inspect
        `.bfs-installer-resume.conf` and require one `RECOVERY_MD=`
        entry for the Linear/JBOD array plus both expected
        `RECOVERY_LUKS=` entries before treating this regression as
        passed.

## r115 runtime-confirmed failure cleanup / layered-storage preservation --- 2026-08-20

-   [x] **FIX IMPLEMENTED in installer r55 / runtime regression pending:
    preserve the complete active storage stack after a caught
    installation failure.**
    -   Live JBOD -\> LUKS -\> LVM testing proved `/dev/md0` was
        successfully created and `/dev/mapper/cryptraid` existed long
        enough to become an LVM PV; the later failure was the
        `useradd sys` group-name collision, not JBOD/LUKS creation.
    -   Runtime inspection after leaving the installer showed
        `cryptroot` still active but `/dev/md0` stopped and `cryptraid`
        gone. The EXIT cleanup was unwinding installer-owned VGs, LUKS
        mappings, and MD arrays, producing a partially torn-down stack
        after a recoverable failure.
    -   Installer r55 now sets `KEEP_MOUNTS=yes` immediately when
        `run_chroot_installer` returns a caught nonzero status,
        preserving mounts, LVM, LUKS, and MD state for inspection and
        Install / Retry.
    -   Quit after a failed attempt now explicitly offers: **Leave
        storage active for recovery / inspection**, **Cleanly deactivate
        installer-owned storage**, or **Back to installer**.
    -   A fully successful retry clears failure-preservation mode
        (`KEEP_MOUNTS=no`) so normal successful final cleanup can
        proceed.
    -   Failure dialog wording now states that the complete active
        target storage stack is preserved and explains the Quit
        behavior.
    -   Static validation: `bash -n` passes for installer r55.
    -   Runtime regression: recreate Linear/JBOD -\> LUKS -\> LVM,
        trigger a controlled chroot failure, verify `/dev/md0`, all
        expected `/dev/mapper/*` LUKS mappings, VGs/LVs, and target
        mounts remain active; retry successfully; separately test both
        Quit choices.

## r114 implementation pass --- runtime UI/account/JBOD fixes --- 2026-08-20

-   **Bootstrap r59 created:** `[AVAILABLE]` is now bright yellow in
    both Dialog and text-mode bootstrap status rendering; green remains
    reserved for completed/success states and red for
    pending/unavailable states.
-   **Installer r54 created:** main-menu `[AVAILABLE]` /
    `[RETRY AVAILABLE]` statuses are bright yellow, completed/configured
    states are green, and pending/incomplete/unavailable states are red.
-   **Linear/JBOD LUKS-selector dedup fixed:** active MD devices are
    enumerated from every `/proc/mdstat` array line (including
    `linear`), `lsblk` paths are canonicalized, and every candidate path
    is recorded in a `seen` set before display. This addresses the live
    `/dev/md0` repeated once per JBOD member symptom and applies to all
    MD types.
-   **Users & Groups review reworked:** Primary and Additional accounts
    now use consistent `User`, `Type`, `Groups`, `Login`, and `Password`
    fields with compact `[STANDARD]` / `[SYSTEM]` markers and wrapped
    Standard-group display.
-   **Account-review mojibake fixed:** Unicode em-dash separators were
    removed from the account modify/remove/review paths in favor of
    ASCII separators for the forced POSIX installer locale.
-   **Theme persistence fixed for chroot dialogs:** the active generated
    `DIALOGRC` is copied into the target before chroot configuration and
    exported by the chroot installer, so optional-password/account
    dialogs use the theme selected in the live installer even though the
    chroot is launched through `env -i`. The temporary target copy is
    removed during installer cleanup.
-   **Username/group collision validation added:** primary and
    additional account names are checked against the extracted target
    group database and the BFSOS `aaa_filesystem/group` source before
    they are accepted. The chroot also performs a defensive preflight
    and exits with status 9 rather than letting `useradd -U` fail
    ambiguously if a same-named group exists.
-   **Failure-status propagation fixed:** the real
    `run_chroot_installer` status is retained in
    `SESSION_FAILURE_STATUS`; Quit after a caught failure exits with
    that status instead of forced `0`; the EXIT cleanup also refuses to
    write SUCCESS/0 when a tracked nonzero installation status is
    outstanding. A later fully successful retry still clears the session
    status to 0.
-   **Static validation:** `bash -n` passes for bootstrap r59 and
    installer r54.
-   **Runtime regression next:** retest Linear/JBOD -\> LUKS selector
    uniqueness; choose a non-default theme and verify all chroot
    password dialogs retain it; try reserved-group usernames such as
    `sys` and `audio` and confirm rejection before install; trigger one
    controlled chroot failure and verify the final log footer preserves
    the nonzero status; then retry successfully and verify SUCCESS/0.

## r107 ports synchronization architecture --- migrate BFSOS collections from HttpUp to Git --- 2026-08-19

-   [x] **IMPLEMENTED using the r108 single-main-branch monorepo design
    / network runtime regression pending --- PRE-1.0 PORTS
    INFRASTRUCTURE CHANGE:** Replace BFSOS's HttpUp-based collection
    synchronization with the CRUX ports **git driver** so normal
    `ports -u` synchronizes each BFSOS ports collection directly from
    its Git branch on Codeberg instead of fetching/generated HttpUp
    repository metadata one file at a time. This is intended to
    eliminate the recurring HttpUp/REPO/.httpup metadata failure mode
    that can cascade into hundreds of collection-sync errors.
-   **Current state confirmed from the supplied `/etc/ports/*.httpup`
    files:** `compat-32`, `compiz`, `contrib`, `core`, `gnome`, `lxqt`,
    `opt`, `plasma`, `xfce`, and `xorg` all currently use
    `ROOT_DIR=/usr/ports/<collection>` plus a Codeberg raw-tree URL
    under `BFS-Linux/raw/branch/main/ports/<collection>`. The migration
    must replace these active `.httpup` definitions with `.git`
    collection definitions rather than keeping both active.
-   **Use the existing Codeberg Git repository:** remote repository is
    `https://codeberg.org/bmadonnaster/BFS-Linux.git` (or the final
    canonical BFSOS repository URL if/when the remote is
    renamed/migrated). Do not depend on Codeberg raw-file URLs for
    collection synchronization once this work is complete.
-   **Branch mapping must be verified, not guessed:** enumerate the
    actual remote branches first (for example with
    `git ls-remote --heads <repo-url>`) and record the exact branch
    corresponding to each collection. Expected collection set to
    migrate: `compat-32`, `compiz`, `contrib`, `core`, `gnome`, `lxqt`,
    `opt`, `plasma`, `xfce`, and `xorg`. If a collection is not actually
    stored as a same-named branch, document its real branch/path and
    adapt the migration accordingly rather than silently assuming names.
-   **CRUX git-driver model:** use `/etc/ports/<collection>.git` files
    so the normal CRUX `ports -u` wrapper automatically selects
    `/etc/ports/drivers/git` by file extension. Each definition should
    use the supported git-driver fields `URL=`, `NAME=`, `BRANCH=`, and,
    where useful for explicit BFSOS layout,
    `LOCAL_REPOSITORY=/usr/ports/<collection>`.
-   **Target layout goal:** after migration, `ports -u` should leave the
    normal collection paths intact (`/usr/ports/core`, `/usr/ports/opt`,
    etc.) so `prt-get`, existing `prtdir` entries, installer code, build
    scripts, and package tooling do not need to learn a new ports-tree
    layout merely because the transport changed from HttpUp to Git.
-   **Collection config migration:** create/update the source
    templates/files that BFSOS installs into `/etc/ports/` so each
    active collection has a `.git` definition. Remove/retire the
    corresponding `.httpup` file or rename it inactive so one collection
    is not synchronized by two drivers. Audit any installer/bootstrap
    scripts that generate or copy `/etc/ports/*.httpup` and convert them
    to the git-driver format.
-   **`ports -u` must remain the normal user command:** do not replace
    the CRUX ports wrapper with a BFSOS-only manual
    `git clone`/`git pull` workflow. The desired user experience is
    still `ports -u`; the existing ports wrapper should dispatch to the
    git driver and perform clone/update operations behind that command.
    `prt-get sync` may also be regression-tested because current CRUX
    supports the same driver mechanism, but `ports -u` remains required.
-   **Git becomes a base-system dependency:** add the `git` port/package
    to the BFSOS base package set so a freshly installed system can run
    `ports -u` immediately with git-backed collections. Ensure Git is
    present early enough for any base/bootstrap stage that performs
    ports synchronization. Audit bootstrap ordering/dependencies so the
    switch does not create a bootstrap cycle.
-   **Remove Git from installer optional-package handling:** once Git is
    guaranteed by the base, remove it from installer optional package
    menus/default optional installation lists and any redundant
    `prt-get depinst git`/equivalent installer action. The final review
    should not present Git as an optional add-on when it is required
    infrastructure.
-   **Bootstrap/base archive integration:** ensure newly created base
    rootfs archives already contain Git, `/etc/ports/drivers/git`, and
    the BFSOS `.git` collection definitions. A restored base archive
    must be able to run `ports -u` without first installing Git or
    regenerating HttpUp repository files.
-   **Remove obsolete HttpUp maintenance requirements where no longer
    needed:** audit `bfs-sync-ports.sh`, `bfs-update-ports.sh`,
    repo-generation helpers, installer recovery/update code, bootstrap
    scripts, and documentation for `.httpup-repo.current`,
    `.httpup-urlinfo`, `REPO`, `httpup-repgen`, or raw-Codeberg
    collection assumptions. Retain `httpup` itself only if BFSOS still
    supports third-party/user collections that legitimately use the
    HttpUp driver; do not keep BFSOS's own collections dependent on it.
-   **Do not break third-party CRUX-style collections:** this migration
    is for BFSOS-maintained collections. The generic CRUX ports
    framework should continue to support `.httpup`, `.rsync`, and `.git`
    driver files so users can subscribe to external collections using
    whichever supported driver they require.
-   **First-sync behavior:** on a clean system with an empty
    `/usr/ports/<collection>`, `ports -u` must clone/check out the
    configured branch. On subsequent runs it must update the existing
    local Git-backed collection cleanly and remove/update files in
    accordance with the remote branch. Test a deleted port/file as well
    as added/modified files.
-   **Local-modification policy:** explicitly define what happens when a
    user has uncommitted edits under `/usr/ports/<collection>`. Prefer a
    safe, understandable failure/warning over silently destroying local
    work. Verify the upstream CRUX git driver's behavior and document it
    in BFSOS ports documentation.
-   **Authentication policy:** installed systems should use a
    **read-only HTTPS clone URL** for normal `ports -u`; users must not
    need the maintainer's SSH key or Codeberg credentials merely to
    synchronize public BFSOS ports. Maintainer push workflows remain
    separate and may continue using SSH from the development checkout.
-   **Branch/repository maintenance:** document the maintainer workflow
    for updating each collection branch (checkout/switch branch -\>
    modify ports -\> commit -\> push). If BFSOS later consolidates or
    renames the `BFS-Linux` repository to `BFSOS`, provide a single
    place/template from which all `.git` URL definitions are generated
    so ten collection files do not drift.
-   **Installer/update error handling:** adapt any `ports -u`
    logging/failure parser that assumes HttpUp wording/files. Git
    clone/fetch/checkout failures must surface the collection name,
    remote URL/branch, exit status, and log path without producing
    misleading HttpUp repair instructions. Preserve the installer
    retry/checkpoint behavior already validated around package/download
    failures.
-   **Cleanup migration on existing systems:** provide a safe upgrade
    path that removes/archives old `/etc/ports/*.httpup` BFSOS
    definitions and initializes the matching git-backed collections. Do
    not delete unrelated third-party `.httpup` configurations. Where an
    existing `/usr/ports/<collection>` is not a Git working tree, the
    migration must replace/synchronize it deliberately rather than
    failing because the directory is non-empty.
-   **`prt-get.conf` audit:** verify every migrated collection still has
    the intended `prtdir /usr/ports/<collection>` entry and that
    collection enable/disable policy is unchanged by switching
    transport.
-   **Regression matrix:** (1) clean machine, empty `/usr/ports`, run
    `ports -u`; (2) second `ports -u` with no remote changes; (3)
    upstream add/modify/delete a test port and sync; (4) temporarily
    break one branch/URL and confirm only that collection fails
    clearly; (5) restore it and confirm retry succeeds; (6) verify all
    ten BFSOS collections; (7) verify `prt-get list`/search/depinst sees
    the synchronized trees; (8) verify an external HttpUp collection can
    coexist; (9) verify fresh base archive contains Git and git-driver
    configs; (10) verify installer no longer offers Git as
    optional; (11) verify no BFSOS update path regenerates HttpUp REPO
    metadata.
-   **Release criterion:** do not consider the migration complete until
    a fresh Bootstrap/base build and a fresh installed BFSOS system both
    perform successful Git-backed `ports -u` synchronization for every
    enabled BFSOS collection, followed by normal `prt-get` package
    operations.

## r106 implementation pass / System Settings + account policy + LVM capacity + timing + audit kickoff --- 2026-08-19

-   **Installer r53 created:**
    `scripts/install-bfs-menu-v50-r53-system-settings-users-lvm-timing.sh`.
-   [x] **SYSTEM SETTINGS SUBMENU IMPLEMENTED / runtime regression
    pending:** The long main menu now has one `System Settings` entry.
    Hostname/timezone/locale, console/font, networking, root-account
    policy, Users and Groups, and SSH configuration live underneath it.
    Required child items and the aggregate main-menu entry use explicit
    `[COMPLETE]` / `[INCOMPLETE]` state derived from current
    configuration rather than menu visitation.
-   [x] **STANDARD VS SYSTEM/SERVICE ACCOUNT POLICY IMPLEMENTED /
    runtime regression pending:** Standard users use one centralized
    BFSOS supplementary-group policy
    (`users,wheel,audio,video,optical,cdrom,plugdev,storage,input,render`).
    System/service accounts use a private primary group with no
    supplementary groups unless explicitly selected; they default to
    `/usr/bin/false` and locked password login. An explicitly selected
    interactive service account uses `/bin/bash`.
-   [x] **OPTIONAL PASSWORDS IMPLEMENTED / runtime regression pending:**
    Root, the primary Standard user, additional Standard users, and
    interactive System/service accounts may leave the password blank.
    Blank means the account is explicitly password-locked; it never
    creates an empty-password login. Passwords remain runtime-only and
    are not stored in installer profiles/logs.
-   [x] **USERS/GROUPS MANAGEMENT FLOW IMPLEMENTED / runtime regression
    pending:** Users and Groups now supports primary Standard-user
    configuration, adding Standard/System-service accounts, modifying
    additional-account policy/groups, removing additional accounts, and
    reviewing the resulting account policy. System/service
    supplementary-group input is validated before it is persisted.
-   **Resume profile format:** installer profile header is bumped to v3
    for typed account entries while remaining backward-compatible with
    older `ADDITIONAL_USER=` entries, which load as Standard users.
-   [x] **LVM LIVE CAPACITY UX IMPLEMENTED / runtime regression
    pending:** PV/VG/LV selectors and review screens now show
    human-readable live capacity. PV usable size, VG total/used/free,
    existing LV sizes, current free space, resolved `%FREE`/`%VG`
    allocation, projected free space, and refreshed post-create capacity
    are shown using authoritative LVM state.
-   **IEC size formatting:** human-facing LVM sizes automatically select
    bytes/KiB/MiB/GiB/TiB/PiB/EiB as appropriate instead of exposing raw
    byte/extents values where a human-readable size is useful.
-   [x] **RAW ELAPSED-SECONDS UI FIX IMPLEMENTED / runtime regression
    pending:** the installed `bfs-pkgmk` wrapper now formats
    human-facing elapsed times through one days/hours/minutes/seconds
    helper. `2841s` renders as `47m 21s`; raw `elapsed_seconds` remains
    unchanged for machine-readable logs. `pkgutils` release is bumped
    from 12 to 13.
-   **Static/formatter validation:** `bash -n` passes for installer r53;
    `sh -n` passes for `bfs-pkgmk`; formatter spot tests pass for bytes
    through TiB and elapsed values including `42s`, `4m 12s`, `47m 21s`,
    hours, and days.
-   **Recent runtime confirmations folded forward:** the fresh RAID4 -\>
    LUKS -\> two-PV LVM -\> five-LV Btrfs install completed, survived a
    same-process package/download retry after `linux-firmware` failed,
    and cold-booted successfully. Post-install duplicate checks found no
    duplicate active `fstab`, `crypttab`, `mdadm.conf`, or GRUB
    settings. RAID4 booted 6/6 healthy and the complete layered storage
    stack reconstructed successfully.
-   **`aaa_filesystem` duplicate-group source defect fixed in the
    supplied tree:** duplicate `root`/`bin` records were traced to
    `ports/core/aaa_filesystem/group`, not installer retry/idempotency.
    The supplied project already contains the corrected unique group
    list; retain duplicate-name/GID checks in the core audit.
-   \[\~\] **PRE-1.0 CORE AUDIT STARTED:** use **current MLFS
    development as the primary multilib/toolchain/build-method
    reference**, authoritative upstream as the source of truth for
    current releases/security/build requirements, current CRUX core as a
    distro/package-layout comparison, and ordinary LFS/BLFS development
    only as secondary cross-checks where useful. Do not downgrade a
    deliberate BFSOS point-release update merely to match a stale book
    snapshot.
-   **Kernel/header policy for the audit:** MLFS development explicitly
    permits a newer stable kernel point release unless errata says
    otherwise. BFSOS may track upstream stable point releases; if Linux
    API headers are intentionally advanced beyond the MLFS-tested set,
    require a clean Bootstrap/toolchain/base regression before treating
    the change as validated.
-   **Current live MLFS sanity snapshot used to start the audit:** BFSOS
    already matches the current MLFS development versions for major
    toolchain/base items including GCC 16.2.0, Binutils 2.47, Glibc
    2.44, Coreutils 9.11, Python 3.14.7, Systemd 261.2, Shadow 4.20.2,
    Linux 7.1.8, Util-linux 2.42.2, Wheel 0.48.0, Xz 5.8.3, and Zlib
    1.3.2. Continue the package-by-package source/patch/build/footprint
    audit rather than treating version equality as completion.
-   **Audit report:** `docs/BFSOS-core-audit-r106-20260819.md` records
    the r106 first-pass static checks, 78 directly mapped
    MLFS-development version matches, required-patch coverage, CRUX
    package-management sanity comparisons, and the remaining
    package-by-package work.
-   **Next runtime regression:** exercise r53 account creation
    (Standard, locked-password Standard, noninteractive service,
    interactive service, explicit service groups), System Settings
    status persistence/profile reload, LVM capacity updates across
    multiple PV/LV creations, and a package build long enough to prove
    the `bfs-pkgmk` human-duration path in real installer output.

## r102 System Settings submenu / completion-state UX --- 2026-08-19

-   [x] **IMPLEMENTED in installer r53; runtime regression pending ---
    GROUP SYSTEM CONFIGURATION UNDER ONE MAIN-MENU ENTRY:** Keep the
    already-long installer main menu from growing further by adding a
    **System Settings** submenu rather than adding separate top-level
    entries for users/groups and each additional system setting. The
    main menu should expose one concise `System Settings` entry with an
    aggregate status such as `[INCOMPLETE]` or `[COMPLETE]`.
-   **System Settings contents:** Move/group the system-level
    configuration that must be reviewed or configured before
    installation into this submenu. At minimum account for hostname,
    timezone, locale, console/keyboard settings where applicable,
    network configuration, root-account configuration, Users and Groups,
    and SSH configuration. Preserve existing installer capabilities
    while reorganizing the UX; do not duplicate configuration state in
    two unrelated menu paths.
-   [x] **IMPLEMENTED in installer r53; runtime regression pending ---
    PER-ITEM COMPLETION STATUS:** Every System Settings submenu item
    should visibly report its own state (`[COMPLETE]`, `[INCOMPLETE]`,
    or another existing installer status where appropriate). Returning
    to the submenu after configuring an item must immediately reflect
    the new state.
-   [x] **IMPLEMENTED in installer r53; runtime regression pending ---
    AGGREGATE SYSTEM SETTINGS STATUS:** The main-menu `System Settings`
    entry becomes `[COMPLETE]` only when every **required**
    system-setting requirement is satisfied. Optional configuration must
    not block completion merely because the user did not choose it. The
    completion calculation should derive from actual saved
    configuration/state rather than simply recording that a menu was
    visited.
-   **Users and Groups integration:** Put the r100/r101 account work
    under `System Settings -> Users and Groups`. That screen should
    provide creation/management of **Standard users** and
    **System/service accounts**, modification/removal where safe,
    supplementary-group management, and a concise review of configured
    accounts. Do not expand the main menu with separate
    account-management entries.
-   **Account-policy preservation:** Standard users continue to receive
    the centralized normal BFSOS supplementary-group policy.
    System/service accounts receive their own primary group and no
    supplementary groups by default, while allowing explicitly selected
    supplementary groups. Passwords remain optional; an unset password
    means no usable password credential, never blank-password login.
-   **Completion semantics for accounts:** Do not require creation of a
    System/service account to mark Users and Groups complete. Account
    completion should reflect the installer's actual required account
    policy. An intentionally password-locked account is valid and must
    not remain `[INCOMPLETE]` merely because no password was set.
-   **Dialog-flow goal:** Entering System Settings should present a
    compact checklist-like configuration hub so the user can see at a
    glance what remains. Individual dialogs should explain choices
    before requesting values and avoid repetitive confirmation screens.
    Returning from a child menu must preserve all previously configured
    settings and statuses.
-   **Final review integration:** The installer's final review should
    summarize System Settings from the same underlying state used by the
    submenu, including account types/login state and any unresolved
    required item. Do not allow the final install action to report
    system configuration complete if a required System Settings item is
    still incomplete.
-   **Regression tests:** (1) launch a fresh installer and verify
    required System Settings items begin incomplete as appropriate; (2)
    configure items in arbitrary order and verify their statuses
    persist; (3) verify optional untouched items do not block aggregate
    completion; (4) create Standard and System/service accounts and
    verify r100/r101 policies; (5) verify an intentionally unset
    password does not block completion; (6) leave one required setting
    unfinished and verify the main menu remains `[INCOMPLETE]`; (7)
    complete the final required item and verify
    `System Settings [COMPLETE]`; (8) leave/re-enter the submenu and
    restart/resume the installer and confirm status is reconstructed
    from saved state.

## r101 terminology refinement --- standard user vs system/service account --- 2026-08-19

-   [x] **IMPLEMENTED in installer r53; runtime regression pending ---
    ACCOUNT-TYPE TERMINOLOGY:** Use **Standard user** and
    **System/service account** throughout the installer instead of the
    vague `non-standard` / `restricted user` wording. A Standard user is
    the normal interactive BFSOS login account. A System/service account
    is intended for daemons, services, automation, or deliberately
    restricted-purpose identities.
-   **System/service group policy:** Give a System/service account its
    own primary group by default and **no supplementary groups unless
    explicitly selected**. Do not imply that service accounts can never
    require supplementary groups; some services legitimately need
    explicit membership in one or more functional groups.
-   **System/service login policy:** Default System/service accounts to
    no interactive login/password credential unless the user explicitly
    chooses otherwise. The dialog/review must clearly show the resulting
    login state rather than silently assuming it.
-   **Dialog wording:** Make **Standard user** the normal/default
    account type. Explain both account types before account details are
    requested, and expose any explicit supplementary-group selection for
    System/service accounts as an advanced/custom action.
-   **Regression update:** Test a System/service account with no
    supplementary groups and another with one or more explicitly
    selected supplementary groups; verify only the requested memberships
    are applied.

## r100 user-creation UX / account policy findings --- 2026-08-19

-   [x] **IMPLEMENTED in installer r53; runtime regression pending ---
    STANDARD USER GROUP POLICY:** When creating a **standard user**,
    automatically add that account to the full normal BFSOS
    supplementary-group set already defined/discussed for an interactive
    desktop/admin-capable user. Keep the exact group list centralized in
    one installer policy/helper so the creation dialog, review screen,
    and account-creation command cannot drift apart.
-   [x] **IMPLEMENTED in installer r53; runtime regression pending ---
    SYSTEM/SERVICE ACCOUNT POLICY:** When the user explicitly chooses a
    **System/service account**, create the account with its own primary
    private group and no supplementary groups by default. Do not
    silently add the normal standard-user supplementary groups. Allow
    explicitly selected supplementary groups as an advanced/custom
    action for services that legitimately require them.
-   [x] **IMPLEMENTED in installer r53; runtime regression pending ---
    PASSWORDS MUST BE OPTIONAL:** Do not require a password merely to
    create either a Standard user or System/service account. The user
    must be allowed to leave the password unset.
-   **No-password behavior:** An account created without a password must
    **not** become passwordless-login capable. Leave/mark the password
    authentication state locked/unset so the account cannot authenticate
    with a blank password. The account may later be enabled by
    explicitly setting a password or by configuring another
    authentication method such as SSH keys.
-   **Root/account consistency:** Apply the same safety principle
    anywhere the installer permits an unset password: blank input means
    **no usable password credential**, never an empty password that
    permits login.
-   [x] **IMPLEMENTED in installer r53; runtime regression pending ---
    REDESIGN USER-CREATION DIALOG FLOW:** Rework the user-creation
    Dialog so the account type and consequences are explained before
    asking repetitive questions. The screen should clearly distinguish
    **Standard user** from **System/service account**, summarize the
    automatic group policy for each, and state that passwords are
    optional and that leaving one unset prevents password login.
-   **Suggested flow:** choose account type -\> enter username/full-name
    fields -\> optional password entry -\> concise review/confirmation.
    Do not make the user manually approve every normal standard
    supplementary group when the standard-user policy already defines
    them.
-   **Review visibility:** The final account review should show account
    type, username, whether password login is configured or
    locked/unset, and either the resolved supplementary groups or a
    concise `Standard BFSOS groups` summary with an optional detail
    view.
-   **Validation/safety:** Continue rejecting invalid/duplicate
    usernames and never log, save in profiles, or display entered
    passwords. Do not conflate an intentionally unset password with a
    password-entry error.
-   **Regression tests:** (1) create a standard user and verify the
    complete BFSOS standard supplementary-group set is applied; (2)
    create a System/service account and verify it has no supplementary
    groups unless groups were explicitly selected; (3) create each type
    with no password and verify blank-password login is impossible; (4)
    set a password and verify normal authentication works; (5) confirm
    Back/Cancel and repeated account creation do not lose prior
    installer state or create partial accounts.

## r99 runtime finding --- successful-install resume-state cleanup --- 2026-08-19

-   [x] **IMPLEMENTATION PRESENT in r52-r57 / clean-cycle runtime
    regression pending --- SUCCESSFUL INSTALL MUST CLEAR RESUME FILE:**
    A clean new installer launch from the same BFSOS checkout detected
    `scripts/.bfs-installer-resume.conf` left by the previous
    installation and automatically entered **Previous installation
    detected** recovery. For a genuinely completed successful
    installation, the resume file should not remain behind.
-   **Required behavior:** Preserve `.bfs-installer-resume.conf` across
    failure, interruption, cancellation, or an incomplete install so
    cold-relaunch recovery remains available. Once all required
    completion checkpoints/sanity checks and boot artifacts confirm
    installation success, remove the resume file automatically.
-   **Existing intent:** r52 already contains
    `rm -f "$INSTALLER_RESUME_FILE"` in its completed-install lifecycle;
    verify that the normal fresh-install success path reaches equivalent
    cleanup and that nothing rewrites the resume file afterward.
-   **Development/reused-checkout behavior:** Reusing the same BFSOS
    project directory should not cause the next clean installation test
    to recover a previously completed installation merely because stale
    resume metadata remains in `scripts/`.
-   **Regression test:** Complete a fresh installation successfully,
    exit/reboot normally, verify `scripts/.bfs-installer-resume.conf` is
    absent, then relaunch the installer from the same BFSOS checkout and
    confirm it starts as a fresh install. Separately interrupt an
    installation and verify the resume file remains and recovery still
    activates.

## r97 implementation / recovery UX + completed-install lifecycle --- 2026-08-18

-   **Installer r52 created:**
    `scripts/install-bfs-menu-v50-r52-recovery-ux-complete-state.sh`.
-   **r51 cold-recovery runtime PASSED:** from a cold Gentoo live boot,
    the existing six-disk RAID6 had auto-assembled under a different MD
    node; r51 successfully adopted the active array, requested the
    required LUKS passphrase(s), activated the saved LVM VGs/LVs, and
    restored the saved Btrfs/filesystem layout without manual storage
    reconstruction.
-   **Recovery prompt order fixed:** the installer now displays
    **Previous installation detected** and explains the non-destructive
    MD -\> LUKS -\> LVM -\> filesystem recovery process **before** any
    LUKS password prompt. The dialog explicitly warns that encrypted
    storage may request passphrases and that passphrases are never
    stored.
-   **Completed-install detection implemented:** after storage recovery,
    r52 reloads persistent target checkpoints and distinguishes a
    genuinely incomplete installation from stale resume metadata. A
    target is considered complete only when `base_extracted`,
    `accounts_configured`, `packages_complete`,
    `system_config_complete`, and `bootloader_complete` are all present,
    the BFSOS base sanity checks pass, and selected GRUB boot artifacts
    exist.
-   **Observed completed target:** the recovered/boot-tested
    installation contained all five completion checkpoints, no
    `last_failure`, `/boot/grub/grub.cfg`, the BFS EFI loader, kernel
    `7.1.8-BFS-Linux`, and its initramfs. Therefore offering Install /
    Retry was incorrect for that target.
-   **Stale resume lifecycle fixed:** when a recovered target is already
    complete, r52 clears the stale resume file, reports **Installation
    already complete**, and does not ask the user to rerun installation.
-   **Main-menu completed state:** option 11 becomes **Installation
    Complete \[COMPLETE\]** for the recovered completed target.
    Selecting it only explains that no retry is required; it cannot
    accidentally restart the install transaction. Chroot remains
    available for inspection.
-   **Incomplete recovery behavior retained:** if any required
    completion checkpoint/sanity check is missing, the installer reports
    **Recovery complete** and presents the normal **Install / Retry
    \[RETRY AVAILABLE\]** path.
-   **Static validation:** `bash -n` passes for r52.
-   **Next clean-cycle test:** rebuild the BFSOS base from a fresh
    Bootstrap, perform a full new install, boot the installed system,
    then cold-boot the live environment and verify recovery both (a)
    during an intentionally incomplete installation and (b) against the
    fully completed installation where stale retry state must not be
    offered.
-   **Remaining MD layout coverage:** the installer explicitly supports
    Linear/JBOD, RAID0, RAID1, RAID4, RAID5, RAID6, and RAID10. The
    tracker still records RAID6 as the recently runtime-confirmed
    creation path; do not mark the other RAID levels complete solely
    from static support. Linear/JBOD is a useful next storage-layout
    test, but it is not the only historically pending RAID-level
    regression unless the other levels have been runtime-tested outside
    this tracker.

## r96 implementation / cold-recovery + final-validator pass --- 2026-08-18

-   **Installer r51 created:**
    `scripts/install-bfs-menu-v50-r51-md-identity-fstab-status-fixes.sh`.
-   **Cold MD recovery root cause confirmed:** Gentoo auto-assembled the
    saved six-member RAID6 as `/dev/md127` in `auto-read-only` state.
    r50 then tried to assemble the same members into the saved pathname
    `/dev/md0`; `mdadm` reported every member busy. Recovery was
    running, but it incorrectly treated the MD device node as persistent
    identity.
-   **Stable MD identity fix:** r51 adopts an already-active MD array by
    persisted MD UUID when available, with an exact normalized
    member-set fallback for older r49/r50 resume profiles that did not
    save an MD UUID. If the array is found under a different node (`md0`
    -\> `md127`), r51 rewrites the in-memory dependent LUKS
    backing-device path and continues recovery instead of trying to
    assemble the members twice.
-   **Future resume profiles now persist MD UUIDs** in addition to saved
    array path/member topology; no secret material is added.
-   **Race-safe MD recovery:** if an explicit assemble loses a race with
    live-environment auto-assembly and returns busy, r51 performs one
    stable-identity re-scan before declaring recovery failure.
-   **Failure/status propagation fixed:** unresolved recovery or
    chroot/install failure sets a session failure status. Exiting after
    such a failure can no longer produce a misleading
    `Result: SUCCESS / Exit status: 0`; a later fully successful retry
    clears the failure state.
-   **fstab false failure fixed:** both generated-fstab validation paths
    now accept `tmpfs` and other standard pseudo-filesystem source
    tokens. The booted-system audit proved line 37
    (`tmpfs /var/cache/pkg/build-work tmpfs ...`) was valid and the
    installed system booted successfully.
-   **Failure-dialog URL noise reduced:** the installer no longer
    scrapes an arbitrary historical URL for generic
    configuration/final-validation failures. URL display is limited to
    operations whose name indicates
    download/source/ports/package/upgrade work.
-   **Install/Retry UI implemented:** when persistent resume state
    exists, option 11 is labeled **`Install / Retry BFS (root)`** with
    **`RETRY AVAILABLE`**; fresh installs retain the normal Install
    label.
-   **Human-readable installer package timing implemented:** status
    output now renders `42s`, `8m 17s`, `48m 13s`, `1h 06m 42s` style
    durations while the machine-readable build-times log keeps raw
    `elapsed_seconds`.
-   **Static validation:** `bash -n` passes for r51.
-   **Runtime regression next:** cold Gentoo boot with the array
    auto-assembled as `/dev/md127` -\> launch r51 -\> verify it adopts
    md127 -\> prompts for both required LUKS passphrases -\> activates
    saved VGs -\> mounts exact Btrfs subvolumes/boot filesystems -\>
    presents Install / Retry without manual storage reconstruction.

### Corrected r95 diagnosis

-   The r95 statement that r50 merely detected the prior installation
    without attempting reconstruction was incomplete. The clean
    cold-boot log proves r50 did enter
    `Resume: reconstructing saved storage stack`; it failed specifically
    at the MD layer because the active array pathname changed from saved
    `/dev/md0` to auto-assembled `/dev/md127`.
-   Observed log sequence: `Resume: reconstructing saved storage stack`
    -\> `Resume: assembling saved MD array /dev/md0` -\> all six saved
    member partitions reported `busy - skipping`.
-   The non-destructive stop behavior passed: r50 did not wipe/recreate
    anything when recovery failed.

## r95 cold-relaunch recovery regression --- 2026-08-18

-   [x] **ROOT CAUSE IDENTIFIED / FIX IMPLEMENTED in r51 --- COLD
    RELAUNCH STORAGE RECOVERY:** The initial r50 observation appeared to
    show detection without reconstruction; later cold-boot logging
    proved recovery did start but failed at the MD layer because the
    saved `/dev/md0` array had auto-assembled as `/dev/md127`. r51 now
    matches/adopts MD arrays by stable identity instead of pathname.
-   Detection alone is not recovery. After accepting the
    previous-installation prompt, recovery must read the saved recovery
    profile and reconstruct the target sufficiently for checkpoint
    validation and `Install / Retry`.
-   Required recovery order for the current layered-storage case:
    assemble required MD arrays (for example `md0`) → open required LUKS
    mappings (prompt for passphrases only when mappings are closed) →
    activate required LVM VGs/LVs → mount the saved root filesystem and
    correct Btrfs subvolume (`@`) → mount separate saved
    filesystems/subvolumes (`@usr`, `@opt`, `@home`, `@var`) → mount
    `/boot` and `/boot/efi` → validate persistent installer
    checkpoints/state.
-   Do **not** ask the user to re-enter disk selections, RAID
    membership, VG/LV names, mountpoints, filesystem choices, or Btrfs
    subvolume names when those values exist in the saved recovery
    profile.
-   After successful reconstruction, return to the main menu with the
    retry state clearly visible as **`Install / Retry`** /
    **`RETRY AVAILABLE`**.
-   Recovery failures must identify the layer that could not be restored
    and must not silently fall through to a normal fresh-install path.
-   **Regression test:** complete enough of an installation to persist
    recovery state, fully unmount `/mnt/bfs`, close/deactivate storage
    layers (or reboot the live environment), relaunch the installer,
    accept previous-installation recovery, and verify automatic MD →
    LUKS → LVM → Btrfs/filesystem remount reconstruction before retry.
-   **Observed r50 failure:** previous installation was detected
    successfully, user selected OK, no storage was mounted/opened, and
    the installer simply displayed the main menu.

## r94 UI finding --- human-readable elapsed times --- 2026-08-18

-   [x] **IMPLEMENTED in current installer/pkgutils / runtime regression
    pending --- HUMAN-READABLE COMMAND/PACKAGE ELAPSED TIMES:** Long
    operations currently report raw seconds (observed:
    `2893s (status 0)`). Format elapsed time as hours/minutes/seconds
    when appropriate, e.g. `42s`, `8m 17s`, `48m 13s`, `1h 06m 42s`,
    while preserving `(status N)`.
-   Apply consistently to installer/build/download/package timing.
-   **Regression test:** verify \<1 minute, \>1 minute, and \>1 hour
    formatting without changing exit-status handling.

## r93 cleanup / recovery-state policy --- 2026-08-18

-   [x] **IMPLEMENTED in r55-r57 / runtime regression pending ---
    FAILURE / RETRY CLEANUP POLICY:** When installation fails or returns
    to the menu for retry, preserve the active target storage stack
    rather than automatically dismantling it. Keep the target
    filesystems mounted, LVM active, required LUKS mappings open, and
    required MD arrays assembled so the user can inspect the failed
    installation and immediately retry.
-   [x] **IMPLEMENTED in r55-r57 / runtime regression pending ---
    SUCCESS CLEANUP POLICY:** After a fully successful installation,
    cleanly unmount the target filesystem tree and release storage
    layers opened/activated by the installer in safe reverse dependency
    order. Track ownership so the installer does not blindly
    close/deactivate unrelated storage that was already active before it
    started.
-   [x] **IMPLEMENTED in r55-r57 / runtime regression pending --- QUIT
    WITH ACTIVE TARGET:** If the user chooses Quit while an
    installer/recovery target is still mounted or otherwise active,
    explicitly ask whether to **leave target storage mounted/open for
    recovery** or **cleanly close the installer target**. Make the
    consequences clear before changing storage state.
-   [x] **IMPLEMENTED in r55-r57 / runtime regression pending ---
    OWNERSHIP-AWARE TEARDOWN:** Maintain per-run ownership/state for
    mounts, LVM VGs, LUKS mappings, and MD arrays. Cleanup should
    normally tear down only layers that the installer itself
    mounted/opened/activated/assembled during that run, unless the user
    explicitly requests full target teardown.
-   [x] **IMPLEMENTED in r55-r57 / runtime regression pending --- SAFE
    TEARDOWN ORDER:** For explicit cleanup, unmount target
    filesystems/subvolumes first, then deactivate installer-owned LVM,
    close installer-owned LUKS mappings, and finally stop
    installer-owned MD arrays when appropriate. Never stop an array
    while dependent mappings/filesystems remain active.
-   [ ] **RECOVERY REGRESSION TESTS:** Test (1) package/install failure
    leaves target inspectable and retryable, (2) successful installation
    performs clean teardown, (3) Quit with active target offers
    preserve-vs-cleanup choice, and (4) pre-existing storage layers are
    not accidentally dismantled.

## r92 UI finding --- Install / Retry menu labeling --- 2026-08-18

-   [x] **IMPLEMENTED in r51-r57 / runtime regression pending ---
    MAIN-MENU RETRY LABEL CLARITY:** When resumable/failed installer
    state exists, change the normal `Install BFS (root)` menu entry to
    **`Install / Retry BFS (root)`** so it is immediately clear that the
    same action resumes/retries the interrupted installation rather than
    blindly starting over.
-   When no resumable state exists, retain the normal
    **`Install BFS (root)`** label.
-   When retry state exists, change the menu status from `[AVAILABLE]`
    to **`[RETRY AVAILABLE]`** (or equivalently explicit wording) so
    recovery state is visible without entering the install action.
-   The retry label/status must be driven by actual detected resumable
    state/checkpoints, not merely by files existing under the target
    mount.
-   **Regression test:** verify fresh install shows the normal Install
    label/status; interrupt an installation after a persistent
    checkpoint is written, relaunch, and verify the main menu visibly
    changes to the retry form before selecting Install.

## r91 implementation / r49 runtime checkpoint regression --- 2026-08-18

-   **Installer r50 created:**
    `scripts/install-bfs-menu-v50-r50-checkpoint-errexit-fix.sh`.
-   **Runtime diagnosis corrected:** r49 did **not** fail because it
    skipped reopening LUKS in the latest test. The log showed
    `Target filesystem plan is already mounted correctly; reusing it for installer retry`,
    which means the manually reopened `cryptroot`/`cryptraid`, VGs, and
    Btrfs subvolume mounts were already active and correctly recognized.
-   **Actual r49 crash:** the installer ERR trap fired on a false
    `[[ -f "$TARGET/var/lib/bfs-installer/$state" ]]` test while
    scanning optional checkpoint marker files. A missing checkpoint is
    normal state, not an error.
-   **Fix:** all affected checkpoint-marker scans now use explicit
    `if [[ -f ... ]]; then checkpoint_mark ...; fi` control flow.
    Missing `packages_complete`, `system_config_complete`, or
    `bootloader_complete` markers therefore remain ordinary
    incomplete-state results and cannot trigger the ERR trap.
-   **Static validation:** `bash -n` passes for r50.
-   **Runtime regression required:** with only `base_extracted`,
    `accounts_configured`, and `last_failure` present, relaunch/retry
    must reuse the mounted target and proceed to the next incomplete
    install/package stage without exiting on a missing checkpoint file.

## r90 implementation / full relaunch-recovery pass --- 2026-08-18

-   **Installer r49 created:**
    `scripts/install-bfs-menu-v50-r49-full-relaunch-recovery.sh`.
-   **Fresh-process storage recovery implemented:** resume profiles now
    persist the non-secret MD member topology, LUKS
    backing-device/mapping names, and LVM VG names. On relaunch,
    recovery runs in dependency order: saved MD arrays -\> saved LUKS
    mappings -\> saved VGs -\> filesystem/Btrfs subvolume mounts -\>
    leaf-device/checkpoint validation. LUKS passphrases are never
    written to disk.
-   **Resume state is now saved before the chroot/package transaction**,
    not only after a caught failure, so an abrupt installer exit during
    package installation still leaves enough topology for the next
    launch.
-   **Btrfs recovery metadata implemented:** profile v2 stores the
    expected data subvolume for each filesystem assignment. r49 also
    reconstructs the deterministic r48-era names (`@`, `@usr`, `@opt`,
    `@home`, `@var`, etc.) when loading an older profile that lacks the
    fourth STORAGE field.
-   **Mount-plan validation hardened:** retry/recovery now validates the
    Btrfs subvolume identity, not merely device-to-mountpoint matching,
    so a top-level ID 5 mount is not mistaken for the installed
    filesystem.
-   **Checkpoint recovery hardened:** after the exact storage tree is
    mounted, r49 reloads persistent target checkpoints. If
    `base_extracted` is missing but `/usr/bin/bash`, `/usr/bin/pkgmk`,
    and `/etc/os-release` prove a valid existing base, the checkpoint is
    safely restored rather than forcing re-extraction.
-   **Declining re-extraction is non-fatal:** choosing No keeps a valid
    existing BFSOS base and continues; an invalid/unknown existing tree
    is preserved and returned to the menu without terminating the
    installer.
-   **Profile validation deduplicated:** repeated references to the same
    missing LV/device are canonicalized and displayed once.
-   **Startup ordering fixed:** when a resume file exists, r49
    loads/reconstructs recovery state before any clean-start unmount
    logic can dismantle the very target it is trying to resume.
-   **Static validation:** `bash -n` passes for r49. Runtime regression
    is still required for fresh-process MD/LUKS/LVM/Btrfs recovery, LUKS
    prompts, checkpoint recognition, and interrupted-download
    continuation.

## r89 relaunch-recovery runtime findings --- 2026-08-18

### Fresh-process recovery must restore the full saved storage stack before validating leaf devices

-   [x] **FIX IMPLEMENTED in installer r49; runtime regression pending
    (2026-08-18):** A fresh r48 launch loaded the saved profile while
    the previous install's MD/LUKS/LVM stack was inactive and
    immediately reported saved LV paths as missing.
-   **Runtime proof:** `mdadm --assemble --scan` successfully
    reassembled the saved six-disk RAID6 as `/dev/md0` with all six
    members healthy (`[UUUUUU]`). The saved LUKS containers on
    `/dev/vda3` and `/dev/md0` were intact; after reopening `cryptroot`
    and `cryptraid`, the saved `bfs-root` and `bfs-raid` LVM stacks
    became available again.
-   **Required recovery order:** load saved profile/state -\> assemble
    only saved MD arrays -\> reopen only saved LUKS mappings -\>
    scan/activate only saved VGs/LVs -\> restore filesystem/subvolume
    mounts -\> validate saved leaf devices/checkpoints -\> resume the
    next incomplete installer stage.
-   Recovery must be **non-destructive** and must never recreate RAID,
    LUKS, PVs, VGs, LVs, filesystems, or signatures merely to resume.
-   Do not store LUKS passphrases. Prompt securely for each required
    saved mapping that is not already open.
-   Every step must be idempotent: already-active arrays/mappings/VGs
    should be verified and reused rather than torn down/recreated.
-   If any layer cannot be restored, show the exact failed layer/device
    and return to a recovery/menu path without formatting or wiping
    anything.

### Recovery must restore Btrfs subvolume mount options for every Btrfs filesystem

-   [x] **FIX IMPLEMENTED in installer r49; runtime regression pending
    (2026-08-18):** Reopening the correct block devices was not enough.
    Mounting the Btrfs filesystems without their saved subvolume options
    exposed the Btrfs top-level trees instead of the installed system.
-   **Observed root behavior:** `/dev/bfs-root/root` mounted without
    `subvol=@` appeared as Btrfs top level (`subvolid=5`) and showed
    `@`/`@snapshots` rather than the installed root.
-   **Observed separate-filesystem behavior:** `/dev/bfs-root/usr`
    mounted without `subvol=@usr` showed `@usr` and `@usr-snapshots`
    directories; `bash` and `pkgmk` appeared missing even though the
    installed `/usr` data was intact inside `@usr`.
-   **Confirmed correct saved layout:**
    -   `/` -\> `/dev/bfs-root/root`, `subvol=@`
    -   `/usr` -\> `/dev/bfs-root/usr`, `subvol=@usr`
    -   `/opt` -\> `/dev/bfs-root/opt`, `subvol=@opt`
    -   `/home` -\> `/dev/bfs-raid/home`, `subvol=@home`
    -   `/var` -\> `/dev/bfs-raid/var`, `subvol=@var`
-   After remounting with the correct subvolumes, `bash`, `pkgmk`, and
    `/etc/os-release` were all present and the installer checkpoint
    files became visible.
-   **Required state persistence:** the resume profile/checkpoint data
    must preserve filesystem type, device, mountpoint, Btrfs
    subvolume/subvolume ID or canonical subvolume name, and any other
    mount options required to reconstruct the exact prior filesystem
    view.
-   **Regression test:** relaunch with all Btrfs filesystems inactive,
    reconstruct the saved stack, mount all five saved Btrfs filesystems
    using their recorded subvolumes, and verify the installed
    tree/checkpoints are visible before validation continues.

### Fresh-process relaunch does not honor existing `base_extracted` checkpoint

-   [x] **FIX IMPLEMENTED in installer r49; runtime regression pending
    (2026-08-18):** After manually reconstructing the storage stack and
    mounting all Btrfs subvolumes correctly, the target contained valid
    installer state:
    -   `base_extracted`
    -   `accounts_configured`
    -   `last_failure`
    -   `/usr/bin/bash` present
    -   `/usr/bin/pkgmk` present
    -   `/etc/os-release` present
-   Despite that, a fresh r48 launch still proceeded to the
    base-extraction path and displayed **`Extract into it anyway?`**.
-   **Required behavior:** once the saved target is reconstructed and
    mounted correctly, detect and trust a valid `base_extracted`
    checkpoint after sanity-checking required base-system files. Skip
    base extraction automatically and advance to the next incomplete
    checkpoint.
-   If the checkpoint file is missing but the target clearly contains a
    valid extracted BFSOS base, offer an explicit safe recovery choice
    such as **Use existing base / Re-extract / Cancel**, with **Use
    existing base** as the non-destructive recovery path.
-   Never force users to overwrite a valid partially installed rootfs
    merely because the installer process was restarted.

### Declining re-extraction is incorrectly treated as fatal installation cancellation

-   [x] **FIX IMPLEMENTED in installer r49; runtime regression pending
    (2026-08-18):** When r48 reached the existing-files warning during
    base extraction, choosing **No** to `Extract into it anyway?`
    resulted in `ERROR: Installation cancelled.` and a fatal installer
    exit.
-   **Required behavior:** in recovery mode, **No** must mean **keep the
    existing extracted base and continue/re-evaluate checkpoints**, not
    terminate the installer.
-   Distinguish a user explicitly cancelling the entire installation
    from declining a destructive/redundant re-extraction step.
-   **Regression test:** with `base_extracted` already complete, force
    the extraction confirmation path and choose No; installer must
    remain alive, preserve the target, and continue from the next
    incomplete stage.

### Profile validation missing-device list must be deduplicated

-   [x] **FIX IMPLEMENTED in installer r49; runtime regression pending
    (2026-08-18):** The r48 Profile validation dialog listed the same
    saved LV paths more than once (including `/dev/bfs-root/root` and
    `/dev/bfs-raid/home`).
-   Canonicalize and deduplicate device paths before
    validation/reporting. Preserve deterministic ordering so the warning
    remains easy to audit.
-   The same saved device may legitimately be referenced by several
    installer fields; that must not create duplicate warning rows.

## r88 runtime recovery findings --- 2026-08-18

### Relaunch recovery must reconstruct MD RAID -\> LUKS -\> LVM before profile device validation

-   [x] **FIX IMPLEMENTED in r49-r57 / runtime regression tracked by
    newer recovery items:** After the previous installer process exited
    and its cleanup deactivated the VGs/stopped the MD array, r48 loaded
    the saved profile and immediately reported saved LV paths such as
    `/dev/bfs-root/root`, `/dev/bfs-root/usr`, `/dev/bfs-root/opt`,
    `/dev/bfs-raid/home`, and `/dev/bfs-raid/var` as missing.
-   **Root cause:** profile validation currently checks saved leaf
    block-device paths before reconstructing the storage dependency
    stack that creates those paths.
-   **Runtime confirmation:** `mdadm --assemble --scan` successfully
    reassembled `/dev/md0` as RAID6 with all six members healthy
    (`[UUUUUU]`). `lsblk` then showed `/dev/vda3` and `/dev/md0` as
    intact `crypto_LUKS` containers. `pvs`, `vgs`, and `lvs` remained
    empty because the saved LUKS mappings had not yet been reopened.
-   **Required relaunch order:** load saved profile -\> assemble only
    the saved MD arrays -\> reopen only the saved LUKS mappings -\>
    scan/activate the saved LVM VGs -\> validate saved LV/device paths
    -\> mount the saved target filesystem plan -\> resume installation.
-   **LUKS safety:** never persist passphrases. On relaunch, prompt
    securely for each saved mapping that is required and not already
    open. Reuse an already-open mapping only after verifying that it
    corresponds to the expected backing device.
-   **MD/LVM safety:** recovery must be non-destructive. Do not recreate
    arrays, PVs, VGs, LVs, filesystems, or signatures. Assemble/activate
    only storage recorded by the saved installer state and verify
    identity/topology before reuse.
-   **Idempotence:** every recovery step must tolerate components that
    are already active. A same-process retry and a fresh-process
    relaunch should converge on the same valid storage state without
    unnecessary teardown.
-   **Failure handling:** if a required array cannot be assembled, a
    LUKS mapping cannot be opened, or a VG/LV cannot be activated,
    return to a clear recovery screen without formatting/wiping anything
    and identify the exact layer that failed.
-   **Regression test:** terminate/relaunch the installer after RAID6 +
    LUKS + LVM have been configured, with MD stopped and VGs inactive.
    Verify the installer reconstructs the saved stack in dependency
    order, prompts for required LUKS passphrases, restores the saved
    LVs, mounts the target, and resumes without requiring Storage Setup
    to be redone.

### Profile validation missing-device list contains duplicate LV paths

-   [x] **FIX IMPLEMENTED in r49-r57 / runtime regression tracked by
    newer recovery items:** The r48 Profile validation dialog listed
    `/dev/bfs-root/root` and `/dev/bfs-raid/home` more than once while
    reporting unavailable saved devices.
-   **Required fix:** canonicalize and deduplicate saved block-device
    paths before existence checks and before rendering the
    missing-device dialog. Preserve deterministic ordering so the
    warning is easy to audit.
-   **Regression test:** load a profile in which the same LV is
    referenced by multiple installer roles/state fields and verify each
    missing device is displayed exactly once.

## r87 implementation / installer-recovery pass --- 2026-08-18

-   **Installer r48 created:**
    `scripts/install-bfs-menu-v50-r48-recovery-lvm-download-fixes.sh`.
-   **Same-process Install / Retry recovery hardened:** when the
    target's selected filesystem plan is already mounted correctly after
    a chroot/package failure, r48 reuses it instead of unmounting and
    remounting the target. This directly addresses the observed
    `umount: /mnt/bfs: target is busy` -\> fatal exit on retry.
-   **Download behavior hardened:** pkgutils release 11 removes the
    third-party flat distfile mirror that caused misleading
    first-attempt 404s, retains partial-file continuation, adds
    stalled-transfer detection, and retries truncated/interrupted
    transfers including curl error 18. Bootstrap Stage 2/3 generated
    pkgmk configuration now uses the same policy.
-   **404 diagnosis corrected:** the logged 404s before
    `linux-firmware`, `wpa_supplicant`, and `rdfind` were consistent
    with the configured flat mirror being tried before the actual
    Pkgfile source. The actual Pkgfile URLs were not replaced merely
    because of those mirror misses; the default flat mirror was removed
    instead.
-   **LVM sizing made explicit:** ambiguous bare values such as `50%`
    are rejected. Users must choose `%FREE` or `%VG`; percentage
    requests are checked against free extents, never silently clamped,
    and the calculated effective allocation is shown for confirmation
    before `lvcreate`.
-   **Static validation:** updated Bootstrap, pkgutils Pkgfile, and
    installer r48 pass `bash -n`. Runtime interrupted-download/resume
    and LVM UI tests remain required.

## r84 implementation / regression-audit pass --- 2026-08-18

-   **Installer r47 created:**
    `scripts/install-bfs-menu-v50-r47-tracker-fixes.sh`.
-   **Kernel-selection crash fixed:** `kernel_pkgfile_version()` now
    initializes locals in nounset-safe steps, validates the requested
    port name, and returns `unknown` instead of aborting for
    missing/malformed data. Static `bash -u` tests returned live
    versions for `linux`/`linux-lts` and `unknown` for missing/blank
    requests.
-   **ZRAM review/visibility completed:** the final pre-install review
    already contained ZRAM state/size and is retained; the Current
    storage devices view now adds configured/active ZRAM; the ZRAM menu
    marks the active size with `[CURRENT]`.
-   **MD stale-signature regression repaired:** after a new MD array is
    created, the installer now inspects the array itself for surviving
    filesystem/LUKS/LVM signatures and offers Keep, Remove, or Cancel.
    LVM VGs exposed by stale metadata are deactivated before an
    explicitly approved removal. The new MD array itself remains active.
-   **Partition-screen safety improvement:** disks whose partition
    tables actually changed during the current installer session are
    marked `[MODIFIED THIS SESSION]`; simply opening/exiting `cfdisk`
    does not mark the disk because before/after kernel-visible partition
    fingerprints are compared.
-   **Bootstrap Stage 3 ccache hardened:** when ccache is enabled, Stage
    3 now verifies the BFSOS ccache binary/wrappers before rebuilding,
    prepends `/usr/lib/ccache` to the Stage-3 build PATH from the first
    package, and prints ccache statistics before/after the rebuild.
-   **Bootstrap verification status:** successful option 4 now displays
    bright-yellow `[PASSED!]` rather than green `[COMPLETE]` in both
    Dialog and text menus.
-   **GCC branding fixed:** final GCC now uses
    `--with-pkgversion="BFSOS"`; the package release is bumped to `2`.
    The shipped default/LTS kernel config compiler-text fields were also
    refreshed to `gcc (BFSOS) 16.2.0` (kernel releases bumped to force
    fresh packages). Attribution comments elsewhere in core/non-core
    ports were intentionally not rewritten.
-   **Last-night regression audit:** no malformed `;;;` case terminators
    remain in `bootstrap.sh` or `ports/core/pkgutils/Pkgfile`; both
    scripts parse with `bash -n`. Temporary-toolchain and target UTF-8
    locale generation/validation code remains present. The current clean
    test reached Stage 2 and GCC 16.2 extracted successfully without the
    previous pathname error, confirming the critical temporary-glibc
    locale fix in real use. RAID6 creation also reached a live
    six-member array without the old post-create `wipefs` busy crash,
    confirming that ordering fix for RAID6.
-   **Still requires runtime testing:** failed-download installer
    resume, storage deactivation/MD stop, Back-navigation paths, all
    RAID levels other than the newly retested RAID6, ccache hit/miss
    activity across a full Stage 3, archive restore locale verification,
    and hardware/bare-metal/release/post-1.0 items.
-   **Audit report:**
    `docs/BFSOS-r84-static-regression-audit-20260818.md` records the
    static regression checks and the remaining live tests.

## r74 implementation pass --- 2026-08-18

-   **Installer r46 created:**
    `scripts/install-bfs-menu-v50-r46-tracker-fixes.sh`.
-   **Bootstrap updated:** Stage 1 temporary-glibc UTF-8 locale is now
    required/verified before toolchain archive creation; the archive is
    checked for the locale archive; Stage 2 generates and validates the
    target `C.utf8` locale immediately after glibc installation; Stage 1
    `pkgmk` failure capture was hardened.
-   **pkgutils updated:** release bumped to 10 and `pkgmk` locale
    selection now validates actual charmap usability with the
    libc/toolchain associated with the running `pkgmk`, rather than
    trusting `locale -a` alone.
-   **glibc updated:** temporary glibc now generates and validates its
    own `C.UTF-8` locale archive before GCC pass 2.
-   **Installer fixes implemented:** RAM-backed pkgmk workspace defaults
    on; storage deactivation unwinds filesystems/LVM/dm-crypt/MD and
    reports incomplete cleanup; RAID member signatures are handled
    before `mdadm --create`; ZRAM settings UI is state-aware; kernel
    versions are read from Pkgfiles; package/download failure capture
    and persistent non-secret resume profile/checkpoints were hardened;
    Back/Cancel paths for base archive and optional package selection
    are non-fatal.
-   **Already present and retained:** GPM optional package support and
    `gpm.service` enablement.
-   **GNU source cleanup:** 29 core GNU ports were moved from
    `ftpmirror.gnu.org` to canonical `ftp.gnu.org/gnu`; the hierarchical
    kernel.org fallback remains pending downloader support.
-   **Not falsely marked complete:** hardware/runtime regression tests,
    RC/release documentation milestones, post-1.0 UI roadmap items, and
    the hierarchical GNU mirror fallback. CRUX `PKGMK_SOURCE_MIRRORS` is
    a flat filename cache; a path-aware GNU alternate-host downloader
    still requires a deliberate `pkgmk` download-layer enhancement
    rather than an inert config variable.

### Installer build settings --- RAM-backed pkgmk workspace default

-   [x] **IMPLEMENTED in installer r46; runtime regression pending:**
    `RAM-backed pkgmk workspace` now defaults to `Yes` for new installer
    settings.
    -   Current testing shows the feature enabled, but the installer
        default should explicitly be **Yes** rather than depending on
        inherited/previous settings.
    -   Keep the setting user-configurable so RAM-backed build work can
        still be disabled.
    -   Keep `RAM workspace maximum` defaulting to **Auto**, using the
        installer's calculated recommendation (16G in the current VM
        test).
    -   This is an installer/build-settings default issue, not a
        Bootstrap issue.

### Installer storage deactivation --- active MD RAID arrays are not stopped

-   [x] **FIX IMPLEMENTED in installer r46; runtime regression
    pending:** storage deactivation now unwinds the stack and explicitly
    stops eligible active `mdadm` arrays instead of silently reporting
    success.
-   **Required behavior:** Deactivate storage in dependency order so
    higher layers are removed before the backing MD device is stopped.
-   **Expected order:** unmount filesystems -\> deactivate LVM
    logical/volume groups as applicable -\> close dm-crypt mappings as
    applicable -\> stop active MD RAID arrays.
-   **MD cleanup:** Stop installer-managed/selected arrays with
    `mdadm --stop <array>` and verify they disappear from `/proc/mdstat`
    before returning to the storage menu.
-   **Safety:** Do not blindly stop unrelated host/live-environment
    arrays. Limit cleanup to arrays created, assembled, or explicitly
    selected by the installer session/topology.
-   **Error handling:** If an array cannot be stopped because it is
    still busy, show a useful Dialog error identifying the remaining
    dependency/device rather than silently reporting successful
    deactivation.
-   **Regression test:** Create/assemble RAID6, optionally layer LVM on
    it, choose Deactivate storage, and verify filesystems/LVM are
    deactivated in order and the MD array is no longer active without
    requiring a manual `mdadm --stop`.

### Installer base package selection --- Back closes installer

-   [x] **NAVIGATION HARDENED in installer r46; runtime regression
    pending:** Back/Cancel from the relevant
    base-archive/package-selection Dialog paths is explicitly captured
    and returns to the prior installer screen instead of propagating a
    nonzero Dialog status.
-   **Required behavior:** Treat the Dialog **Back/Cancel** navigation
    result as normal installer navigation, not as a fatal error or
    installer exit.
-   **Audit:** Check the base-package selection function's Dialog
    return-code handling and make sure a nonzero Back/Cancel result
    cannot fall through into `set -e`, an ERR trap, or a top-level exit
    path.
-   **State preservation:** Returning from base package selection should
    preserve the installer's existing configuration and package
    selections unless the user explicitly changes or resets them.
-   **Regression test:** Enter base package selection, choose **Back**,
    verify the previous installer menu is displayed, verify the
    installer process remains running, then re-enter package selection
    and confirm prior state is intact.

### Installer ZRAM settings screen --- state/action mismatch and no-op Enable option

-   [x] **FIX IMPLEMENTED in installer r46; runtime regression
    pending:** the ZRAM screen is state-aware and shows only the
    meaningful Enable/Disable action, with status/size refreshed after
    each change.
-   **Rework the ZRAM screen** so the available action reflects the
    current state rather than presenting dead/no-op choices.
-   When ZRAM is enabled, show a clear `Current status: Enabled` and
    current size, and offer **Disable ZRAM** plus the size choices.
-   When ZRAM is disabled, show `Current status: Disabled` and offer
    **Enable ZRAM** plus the size choices as appropriate.
-   After enabling/disabling ZRAM or changing its size, immediately
    redraw/refresh the Dialog so the displayed status and size reflect
    the new setting.
-   Avoid simultaneously presenting both **Enable ZRAM** and **Disable
    ZRAM** as if both are meaningful actions.
-   Preserve the existing 50%, 100%, 150%, 200%, and custom-size
    choices.
-   **Regression test:** Toggle ZRAM on/off repeatedly, select each
    percentage/custom size, verify the status line updates immediately,
    and verify no selectable menu entry silently performs a no-op.

### Installer kernel selection --- simplify descriptions and show live Pkgfile versions

-   [x] **IMPLEMENTED in installer r46; runtime regression pending:**
    kernel selection now reads versions dynamically from the
    corresponding Pkgfiles and keeps the LTS annotation to the concise
    `Debian patch set` label.
-   **Default kernel:** Display only the kernel name and its current
    version, read dynamically from the default kernel port's `Pkgfile`.
-   **LTS kernel:** Display the kernel name, its current version read
    dynamically from the LTS kernel port's `Pkgfile`, and a short note
    such as **`Debian patch set`**.
-   Do not hard-code either kernel version in the installer; kernel
    updates should automatically be reflected by reading the
    corresponding `Pkgfile`.
-   Keep the LTS description concise; no additional long explanatory
    text is needed.
-   **Regression test:** Change each kernel port's version in its
    `Pkgfile` and verify the installer kernel-selection screen displays
    the updated versions without requiring an installer code change.

### Installer failed download / package failure --- resume path confirmed broken

-   [x] **RECOVERY HARDENED through installer r48; RELEASE-BLOCKING
    runtime regression still required:** package/download failures are
    captured, resume/checkpoint state is preserved, and r48 additionally
    reuses an already-correct target mount plan on same-process Install
    / Retry instead of triggering the fatal busy-unmount path seen in
    the linux-firmware test.
-   **Latest observed test result (r47): FAILED.** Continue -\> Install
    after the interrupted linux-firmware download reached a busy-target
    remount failure. r48 contains a direct fix for that same-process
    retry path; relaunch-after-process-exit remains a separate runtime
    test because encrypted/LVM layers may require user reactivation.
-   **Startup/resume audit required:** Trace persisted checkpoint/state
    loading, target mount/state detection, storage topology
    reconstruction, startup validation, and all
    `set -e`/ERR-trap/nonzero-return paths that run before the main
    installer menu is restored.
-   **Required relaunch behavior:** A relaunch after an interrupted
    package phase must reconstruct the prior configuration,
    validate/remount the existing target as needed, force completed
    filesystem format actions to `keep`, and return to the installer
    menu with **Install / Retry** available rather than terminating.
-   **Existing intended behavior:** The installer already has a
    checkpoint/resume design intended to preserve completed
    destructive/setup stages and allow a later **Install / Retry** to
    continue from the failed/incomplete package transaction.
-   **Current problem:** Real failed-download testing still shows that
    this recovery path is not fully reliable; the installer can
    terminate before the resume UI/checkpoint flow is reached.
-   **Required behavior on download/package failure:** Catch nonzero
    statuses from package/source download, `ports -u`, `prt-get sysup`,
    `prt-get depinst`, package builds, and optional package installation
    without terminating the installer process.
-   **UI behavior:** Show the normal Dialog failure message with
    package/operation, URL when detectable, exit status, and preserved
    installer/package log path, then provide **Continue/Back** to return
    to the installer main menu.
-   **Resume behavior:** On rerun or **Install / Retry**, preserve and
    validate existing storage/filesystem/base-extraction state, force
    prior format actions to `keep`, re-run `ports -u` so repaired source
    metadata is picked up, retry only the failed/incomplete package
    transaction, and continue from the next incomplete checkpoint.
-   **Safety:** Never automatically repartition, recreate RAID/LUKS/LVM,
    reformat filesystems, or re-extract the base archive if those stages
    already completed successfully.
-   **Checkpoint verification:** Confirm the installer persists enough
    state to distinguish at least `base_extracted`, `packages_complete`,
    `system_config_complete`, and `bootloader_complete`, and that state
    survives an installer process exit/relaunch when possible.
-   **Regression test:** Intentionally break one package URL, start
    installation, allow the download to fail, verify the installer stays
    alive and returns to its menu, repair the URL from another terminal,
    select **Install / Retry**, verify `ports -u` reruns, verify no
    destructive/setup stages repeat, and confirm installation resumes
    through completion.

### Installer MD RAID creation --- signature/wipe ordering is backwards for all RAID levels

-   [x] **FIX IMPLEMENTED in installer r46; RAID6 runtime regression
    PASSED 2026-08-18:** the common MD RAID path checks/clears approved
    stale signatures on member devices **before** `mdadm --create`; the
    post-create `wipefs -a "$array_device"` operation was removed. A new
    six-member RAID6 was created and remained active without the prior
    `wipefs: Device or resource busy` abort. Other RAID levels still
    need regression coverage.
-   **Scope:** Treat this as a common `create_raid_array()` bug
    affecting every MD RAID level that uses this path (RAID0/1/5/6/10
    and any other supported MD level), not as a RAID6-only issue.
-   **Observed failure:** `mdadm` reports the new array started
    successfully, followed immediately by `wipefs` failing to probe the
    active array because it is busy.
-   **Required ordering:** Select member devices -\> detect stale
    filesystem/RAID signatures on the member devices -\> ask the user
    for erase confirmation when needed -\> clear approved stale
    signatures/old MD metadata from the member devices -\> run
    `mdadm --create` -\> allow the newly created `/dev/mdX` to remain
    active for subsequent filesystem/LUKS/LVM setup.
-   **Do not:** Run a blanket post-create `wipefs -a` on the newly
    active `/dev/mdX`.
-   **Safety:** Signature confirmation must identify exactly which
    member device/signature will be erased. Never wipe unrelated devices
    or an already-created active array merely as part of RAID creation.
-   **Regression tests:** Exercise every installer-supported MD RAID
    level. Test both clean member disks and members containing stale
    filesystem/MD signatures. Confirm the erase question occurs before
    array creation, the approved member signatures are cleared,
    `mdadm --create` succeeds, `/dev/mdX` remains active, and the
    installer continues without a `wipefs` busy failure.

### Installer package-download failure --- partial download lost and recovery remount path aborts

-   [x] **FIX IMPLEMENTED in installer r48 / runtime regression pending
    (2026-08-18):** During optional package installation,
    `linux-firmware` failed after an interrupted large download. r48 now
    recognizes when the selected target filesystem plan is already
    mounted correctly and reuses it for Install / Retry rather than
    forcing the unmount/remount path that previously hit a busy
    `/mnt/bfs` and terminated the installer.
-   **Observed linux-firmware failure:** Primary kernel.org URL returned
    HTTP 404; a subsequent transfer then downloaded about 104 MiB of a
    \~609 MiB archive before curl exited with error 18
    (`end of response ... bytes missing`).
-   [x] **Download-resume code hardened:** BFSOS pkgmk configuration
    keeps `--continue-at -`, adds stalled-transfer detection
    (`--speed-limit 1024 --speed-time 30`), and uses bounded
    `--retry-all-errors` retries so curl error 18/truncated transfers
    can retry from the partial file. Runtime verification with a
    deliberately interrupted large file is still required.
-   **Retry policy:** Distinguish hard failures such as HTTP 404 from
    transient transport failures such as truncated responses/timeouts.
    Hard-failed URLs should advance quickly to the next valid source;
    interrupted transfers should retry/resume the same source a limited
    number of times before falling back.
-   **Integrity:** Never trust a resumed/partial file without the normal
    pkgmk checksum/signature verification after the complete file is
    assembled.
-   **Installer recovery bug:** After the package failure, the installer
    entered a target-filesystem remount/recovery path and attempted to
    unmount `/mnt/bfs`; `umount` reported `target is busy`, followed by
    `ERROR: Could not unmount /dev/bfs-root/root from /mnt/bfs`, and the
    installer terminated.
-   [x] **Required recovery behavior implemented in r48:** A
    canonicalized mount-plan check verifies root/boot/EFI/home/extra
    assignments. If they already match, r48 reuses the live target and
    proceeds directly back into the retry path without destructive
    storage teardown.
-   **Busy-target handling:** Detect processes/chroots/mounts keeping
    `/mnt/bfs` busy, report them meaningfully if cleanup is genuinely
    required, and never convert a recoverable package-download failure
    into a full installer exit merely because the target is already
    mounted.
-   **State preservation:** Preserve completed package installs. In this
    run many dependencies/optional packages had already installed
    successfully before `linux-firmware` failed; retry should resume at
    the failed/incomplete package rather than reinstalling completed
    work.
-   **Regression test:** Force an interrupted large package download
    after \>100 MiB is received. Verify the partial file is retained,
    retry resumes rather than restarting, installer stays alive, storage
    remains intact, completed packages are not redundantly reinstalled,
    and the failed package can be retried to completion.

### Installer source URLs --- stale 404 primaries still present for linux-firmware, wpa_supplicant, and rdfind

-   [x] **ROOT CAUSE CORRECTED / CONFIG FIX IMPLEMENTED (2026-08-18):**
    The initial 404s seen before several otherwise-successful downloads
    were caused by the configured flat `PKGMK_SOURCE_MIRRORS` cache
    being tried before the real Pkgfile URL. pkgutils release 11
    disables that third-party flat mirror by default, so healthy
    upstream URLs are attempted directly.
-   **Observed log behavior:** `linux-firmware`, `wpa_supplicant`, and
    `rdfind` each showed an initial 404 while the flat mirror policy was
    enabled. Subsequent behavior showed the real source could still be
    attempted; do not mislabel the Pkgfile URL as stale solely from the
    mirror miss.
-   [x] **Required action completed for this regression:** Remove the
    misleading default flat mirror rather than rewriting valid package
    source URLs. Keep source URLs independently maintainable and verify
    them when a failure is demonstrably from the source host itself.
-   Keep backup/fallback handling, but the first configured URL should
    be expected to work under normal conditions.
-   **Regression test:** Clear cached sources and build each affected
    package; verify the primary URL succeeds without an initial 404 and
    fallback is only used when intentionally simulated.

### LVM percentage sizing --- mixed fixed-size and percentage LVs produce confusing allocation

-   [x] **FIX IMPLEMENTED in installer r48 / runtime UI regression
    pending (2026-08-18):** Ambiguous bare percentages are no longer
    accepted. The LVM UI requires explicit `%FREE` or `%VG`, validates
    requested extents against current free extents, refuses
    over-allocation instead of silently clamping, and shows the
    effective allocation before creation.
-   **Observed live test:** `bfs-root` VG was approximately
    `246.98 GiB`. User selected `root = 100G`, `usr = 50%`, and
    `opt = 50%`. Resulting LVs were approximately:
    -   `root = 100.00 GiB`
    -   `usr = 123.49 GiB`
    -   `opt = 23.49 GiB`
-   **Likely current behavior:** `usr = 50%` appears to have been
    calculated against the original total VG size
    (`246.98 / 2 ≈ 123.49 GiB`), leaving only `23.49 GiB` for `opt`; the
    final percentage request then appears to have been reduced/clamped
    to the remaining free space.
-   **UX problem:** Two `50%` selections alongside a fixed `100G` LV do
    not intuitively communicate that one LV may receive \~123.49 GiB
    while the other receives only \~23.49 GiB. The installer must not
    silently reinterpret or clamp percentage requests without making the
    result explicit.
-   **Implemented semantics:** `%FREE` means a percentage of the
    currently free extents at the moment the LV is created; `%VG` means
    a percentage of total VG extents. A bare `50%` is rejected with an
    explanation rather than silently interpreted. A future declarative
    multi-LV planner could provide pooled percentage shares, but r48
    removes the unsafe ambiguity from the current imperative workflow.
-   If percentages intentionally mean `%VG` rather than a share of
    remaining free space, label that explicitly in the UI and
    reject/resolve combinations whose requested total exceeds available
    extents instead of silently shrinking the last LV.
-   [x] **Pre-creation review implemented for each LV:** Before
    `lvcreate`, r48 shows the requested percentage/fixed size and, for
    percentage requests, the calculated effective MiB/extents, then
    requires confirmation.
-   **Validation:** Ensure rounding to physical extents cannot
    over-allocate the VG, and never depend on creation order to produce
    materially different results unless the UI explicitly describes
    sequential allocation.
-   **Regression tests:** Test fixed-only, percentage-only, and mixed
    layouts, including `100G + 50% + 50%`, reversed LV order,
    percentages totaling under/at/over 100%, and very small remaining
    free-space cases.

### Final pre-install review --- include ZRAM configuration

-   [x] **IMPLEMENTED / STATICALLY VERIFIED in installer r47
    (2026-08-18):** The final **BFS Installation review** includes the
    selected ZRAM Enabled/Disabled state and configured size.
-   **Required review fields:** Show whether ZRAM is
    **Enabled/Disabled** and, when enabled, the configured size (for
    example `100% of RAM`, `200% of RAM`, or the exact custom size).
-   If the installer computes an effective size from a percentage, the
    review may also show the resolved size in GiB/MiB where practical.
-   The review must reflect the currently selected installer settings,
    not merely the live environment's current `/dev/zram0` state.
-   If ZRAM is disabled, show that explicitly rather than omitting the
    entry.
-   Keep the ZRAM review near other memory/swap/storage settings so the
    user can verify it before committing to installation.
-   **Regression test:** Configure several predefined ZRAM percentages,
    a custom size, and Disabled; open the final review each time and
    verify the displayed ZRAM state/size exactly matches the installer
    configuration.

### Kernel selection crashes installer --- `kernel_pkgfile_version()` uses unbound `package`

-   [x] **FIXED in installer r47 / nounset static regression passed
    (2026-08-18):** The r46 kernel-selection crash from an unbound
    `package` local is corrected; runtime Dialog regression remains to
    be exercised.
-   **Observed failure:** `line 3728: package: unbound variable`.
-   Installer error report identifies:
    -   Function: `configure_kernel`
    -   Failing command:
        `linux_version="$(kernel_pkgfile_version linux)"`
    -   Caller: line 3739
    -   Exit status: `1`
-   **Likely defect location:** `kernel_pkgfile_version()` around line
    3728 references shell variable `package` without safely initializing
    it from the function argument (for example `local package="${1:-}"`)
    before use. With `set -u`/nounset active, this immediately aborts
    the installer.
-   **Required fix:** Audit the entire `kernel_pkgfile_version()` helper
    and its callers. Explicitly initialize every local variable before
    reference, validate the requested kernel package/port name, and make
    missing/malformed Pkgfile/version information return a safe fallback
    instead of terminating the installer.
-   Dynamic kernel-version display must remain informational/UI logic
    and **must never be capable of crashing the installer**.
-   Verify both normal/default kernel and LTS kernel lookups, including
    the requested LTS description/branding behavior.
-   **Regression tests:**
    1.  Open kernel selection with valid default and LTS Pkgfiles and
        verify both versions display correctly.
    2.  Test a missing Pkgfile, missing `version=` field, empty value,
        and malformed value; installer must remain running and show a
        sensible `unknown`/unavailable fallback.
    3.  Run with nounset (`set -u`) enabled and confirm no
        unbound-variable failure.
    4.  Back out of kernel selection and re-enter it repeatedly without
        installer termination.

### Current storage devices view --- include configured ZRAM swap

-   [x] **IMPLEMENTED in installer r47; runtime UI regression pending
    (2026-08-18):** Current storage devices now includes
    configured/active ZRAM state and size.
-   **Current behavior:** The storage tree shows physical disks,
    partitions, MD RAID, LUKS mappings, LVM PV/LVs, filesystems, etc.,
    but the configured ZRAM device is absent.
-   **Desired behavior:** Show the ZRAM swap device (normally
    `/dev/zram0`) with a clear type/status such as `zram swap`, its
    configured/effective size, and whether it is currently active if
    that information is available.
-   If ZRAM is configured for installation but has not yet been
    instantiated in the live environment, show a separate concise entry
    such as `ZRAM swap: enabled, 100% of RAM (configured)` rather than
    pretending a `/dev/zram0` device already exists.
-   Keep ZRAM visually distinct from persistent block storage so users
    do not mistake it for a disk/partition.
-   The displayed size/state should update after changing the ZRAM
    configuration.
-   **Regression test:** Enable/disable ZRAM and test predefined/custom
    sizes; reopen Current storage devices and verify the displayed ZRAM
    state and size match the installer configuration.

### ZRAM size menu --- clearly mark the currently selected size

-   [x] **IMPLEMENTED in installer r47; runtime UI regression pending
    (2026-08-18):** The current predefined/custom ZRAM size is marked
    `[CURRENT]` directly in the menu.
-   **Observed behavior:** With ZRAM enabled at 100%, the choices `50%`,
    `100%`, `150%`, `200%`, and `Custom` all look identical. The blue
    highlight only indicates the current cursor position and can
    therefore be mistaken for the configured value.
-   **Desired behavior:** Add an unmistakable marker to the active
    configuration, for example `Size: 100% of RAM [SELECTED]` or
    `[CURRENT]`, and update it immediately whenever the user chooses
    another size.
-   If a custom size is active, show the actual configured custom value
    and mark the Custom entry as selected/current.
-   Keep the header summary, but make the menu state independently
    understandable without relying on the header.
-   Consider using the same selected/current-state convention on other
    installer option menus where cursor highlight and configured value
    can otherwise be confused.
-   **Regression test:** Select each predefined ZRAM size and a custom
    size, return to/reopen the screen, and confirm exactly one choice
    clearly reflects the persisted current configuration.

### Newly created MD RAID --- detect surviving LVM metadata and ask whether to preserve or remove it

-   **LIVE TEST UPDATE (2026-08-18):** Stale LVM signatures from the
    previous crashed installation were detected/cleared as expected
    during the new installer test. Continue testing the full
    Keep/Remove/Cancel branches independently, but the stale-signature
    cleanup path has now succeeded in a real reused-storage scenario.
-   [x] **IMPLEMENTED in installer r47; runtime Keep/Remove/Cancel
    regression pending (2026-08-18):** New MD arrays are inspected for
    surviving signatures including LVM metadata and the user is
    explicitly offered Keep, Remove, or Cancel.
-   **Observed during testing:** A newly created RAID6 `/dev/md0`
    immediately appeared as an `LVM2_member` and caused the old
    `bfs-raid` VG with `home` and `var` LVs to reactivate, even though
    the RAID member disks had just been repartitioned/recreated.
-   **Detection:** Inspect the newly available `/dev/mdX` with
    appropriate non-destructive signature/LVM discovery (`wipefs`
    read-only inspection, `pvs`, etc.) before using it for LUKS, a new
    PV, formatting, or other destructive operations.
-   **If existing LVM is detected:** Present an explicit choice
    explaining that existing LVM metadata/logical volumes were found on
    the RAID device:
    -   **Keep existing LVM** --- preserve the PV/VG/LVs and do not wipe
        or overwrite their metadata.
    -   **Remove existing LVM** --- clearly warn that the existing
        VG/LVs and their data will be destroyed; deactivate the affected
        VG/LVs safely, then remove the stale LVM signature/metadata from
        the selected MD device only.
    -   **Cancel / Back** --- make no changes.
-   Never automatically destroy an existing LVM signature merely because
    the MD array was newly created; surviving metadata may contain data
    the user intentionally wants to recover or reuse.
-   If the user chooses removal, verify that no LV is mounted/in use,
    deactivate the correct VG, operate only on the explicitly selected
    `/dev/mdX`, refresh LVM/device state, and confirm that `LVM2_member`
    is gone while the MD array itself remains active.
-   After removal, refresh subsequent device selectors so `/dev/mdX`
    becomes available for workflows such as **RAID -\> LUKS -\> LVM**.
-   **Regression test:** Recreate an MD array whose data area still
    contains a valid LVM PV/VG, confirm the installer detects it, test
    Keep/Remove/Cancel independently, and verify no unrelated disk or VG
    is modified.

### Installer partition-disk screen --- identify disks modified during current session

-   [x] **IMPLEMENTED in installer r47; runtime UI regression pending
    (2026-08-18):** Partition disks whose kernel-visible partition
    layout changed are marked `[MODIFIED THIS SESSION]`.
-   **Current problem:** The screen lists only device path and size (for
    example `/dev/vda 250G`), so after editing several similarly sized
    disks it is easy to lose track of which devices were already
    changed.
-   **Preferred behavior:** Keep modified disks visible, but append a
    clear status marker such as **`[MODIFIED]`**, **`[PARTITIONED]`**,
    or **`[CHANGED THIS SESSION]`** after the device/size. Do not
    silently remove a disk from the list merely because `cfdisk`/`fdisk`
    wrote a partition table; disappearing entries could make the user
    think a disk vanished or failed.
-   **Detection/state:** Track devices opened through the installer
    partition editor and mark a disk only after the partitioning tool
    exits successfully and the kernel sees a changed partition table.
    Where practical, compare the before/after partition-table state so
    simply opening and exiting without changes does not falsely mark the
    disk modified.
-   **Refresh:** Run the normal partition-table/device refresh
    (`partprobe`/`udevadm settle` or installer equivalent) after leaving
    the partition editor, then redraw the list with the updated status.
-   **Optional enhancement:** Show a concise partition summary for
    modified disks (for example partition count or key partition
    sizes/types) in a detail/status view without overcrowding the
    primary selector.
-   **Persistence scope:** The marker only needs to represent changes
    made during the current installer session; it does not need to imply
    that an existing disk from before installer startup was modified by
    BFSOS.
-   **Regression test:** On a VM/system with many similar disks, edit
    multiple disks, return to the partition-disk selector after each
    edit, and verify each actually changed disk is clearly marked while
    untouched disks remain unmarked and all disks remain selectable.

### Bootstrap Stage 3 --- ensure ccache is used for the entire rebuild

-   [x] **IMPLEMENTATION HARDENED in bootstrap r84; full Stage-3
    statistics regression pending (2026-08-18):** ccache preflight,
    wrapper PATH from the first Stage-3 package, and before/after
    statistics are now enforced when ccache is enabled.
-   Stage 3 should inherit/use the configured ccache setting
    consistently across every applicable package build.
-   Verify `CC`, `CXX`, compiler wrappers/PATH ordering, and
    `pkgmk.conf` handling so individual ports cannot unintentionally
    bypass ccache unless a package explicitly requires it.
-   Preserve any intentional package-specific ccache exclusions and
    document why they are necessary.
-   Add/check ccache statistics before and after Stage 3 so a test run
    can confirm cache hits/misses are actually being recorded.
-   **Regression test:** Run Stage 3 with ccache enabled, confirm
    applicable package builds invoke ccache, and verify `ccache -s`
    shows Stage-3 activity.

### Bootstrap verification status --- show bright-yellow `[PASSED!]`

-   [x] **IMPLEMENTED in bootstrap r84; runtime menu redraw regression
    pending (2026-08-18):** successful verification now renders
    bright-yellow `[PASSED!]`.
-   **Current behavior:** The Bootstrap menu shows option 4 as green
    `[COMPLETE]`, which looks the same as ordinary completed build
    stages.
-   **Desired behavior:** A successful verification should display
    **bright yellow `[PASSED!]`** in the right-hand status column.
-   Keep build-stage completion states separate from verification
    results: stages may remain `[COMPLETE]`, while the
    verification/check result uses `[PASSED!]`.
-   Ensure the status survives normal menu redraws and accurately
    reflects the most recent successful verification rather than being
    cosmetic-only.
-   **Regression test:** Run option 4 successfully, return to the
    Bootstrap menu, and confirm option 4 displays bright-yellow
    `[PASSED!]` with alignment matching the other status fields.

### GCC version branding --- `Linux From Scratch` string appears in BFSOS compiler output

-   [x] **ROOT CAUSE FOUND / FIXED in r84 (2026-08-18):**
    `ports/core/gcc/Pkgfile` explicitly passed
    `--with-pkgversion="Linux From Scratch"`; it now passes
    `--with-pkgversion="BFSOS"`.
-   **Observed behavior:** The compiler version banner is carrying the
    vendor/package branding string `Linux From Scratch` instead of
    BFSOS/BFS Linux branding or the normal upstream GCC banner.
-   **Required investigation:** Determine exactly where the
    `Linux From Scratch` vendor string is being injected. Audit the GCC
    `Pkgfile`, bootstrap GCC pass configuration flags, GCC
    spec/configure options, patches, environment variables, and any
    copied LFS-era bootstrap code that may set a package version/vendor
    suffix.
-   **Likely areas to inspect:** GCC configure arguments such as
    `--with-pkgversion=...`, any `PKGVERSION`/vendor definitions, Stage
    1/2/3 GCC build functions, and the final installed GCC package
    build.
-   **Desired behavior:** Replace the stale LFS branding with an
    appropriate BFSOS/BFS Linux identifier, or leave the upstream GCC
    banner unbranded if that is preferable. Ensure Stage 1 temporary
    compilers and the final installed compiler do not accidentally
    retain unrelated distro branding.
-   **Regression test:** After rebuilding GCC, verify `gcc --version`
    and `g++ --version` no longer display `Linux From Scratch` and that
    the selected BFSOS/upstream branding is consistent across the final
    installed compiler.

### Bootstrap archive safety / Stage 5 failure handling

-   [x] **IMPLEMENTED in bootstrap r45:** Stage 5 base-rootfs archive
    creation now runs with root privileges so protected files in the
    verified rootfs can be read instead of producing permission-denied
    tar errors.
-   [x] Stage 5 explicitly unmounts and verifies the bootstrap
    bind/virtual mounts are gone before creating the archive, including
    the external sources/packages/build-work mounts.
-   [x] Archive creation now checks the actual `tar` exit status. If
    compression fails, the partial archive is deleted and Stage 5
    returns failure instead of printing a false success message.
-   [x] The completed base archive is immediately tested with `tar -tJf`
    and sanity-checked for required BFSOS files (`/usr/bin/bash`,
    `/usr/bin/pkgmk`, `/etc/os-release`).
-   [x] When Stage 5 is entered through sudo from the interactive menu,
    ownership of the finished archive is returned to the invoking user.
-   [ ] **Regression test:** Re-run Stage 5 and verify no
    `Permission denied` messages occur, the archive passes validation,
    and an intentionally forced tar failure is reported as failure with
    no partial archive retained.

### Bootstrap toolchain archive safety

-   [x] **IMPLEMENTED in bootstrap r45:** Toolchain archive compression
    no longer dumps the complete verbose tar member list to the
    interactive terminal.
-   [x] Toolchain archive creation explicitly checks the compression
    exit status and deletes a partial archive on failure.
-   [x] The archive is verified with `tar -tJf` and sanity-checked for
    the compiler, linker, and `pkgmk` before Stage 1 reports archive
    success.
-   [ ] **Regression test:** On the next clean Stage 1 run, verify
    concise compression output, successful integrity/payload checks, and
    correct failure handling if archive creation is deliberately
    interrupted.

### Bootstrap Stage 5 success-screen cleanup

-   [x] **IMPLEMENTED in bootstrap r45:** After a successful Stage 5
    base archive operation, return directly to the Bootstrap main menu
    instead of showing `Operation completed successfully.` /
    `Press Enter to return to the menu...`.
-   Real Stage 5 failures still report their nonzero status and retain
    the pause so the error can be read.

### Bootstrap Stage 3 success-screen cleanup

-   [x] **IMPLEMENTED in bootstrap r45:** After a successful Stage 3
    rebuild, return directly to the Bootstrap main menu instead of
    showing the redundant success/pause screen.
-   Stage 2 uses the same direct-return behavior after success.

### Bootstrap time synchronization audit

-   [x] **IMPLEMENTED in bootstrap r45:** Root stages launched from the
    interactive Bootstrap menu no longer re-run the startup time
    synchronization when `sudo` re-enters `bootstrap.sh`.
-   A top-level invocation still performs the normal startup
    synchronization; child stage invocations receive
    `BFS_SKIP_TIME_SYNC=yes`.
-   This removes the observed duplicate sync before Stage 3 and Stage 4
    while preserving clock synchronization when bootstrap is initially
    launched.
-   [ ] **Regression test:** Run Stages 1-5 through the interactive menu
    and confirm only the initial bootstrap startup performs time
    synchronization.

### Bootstrap Stage 3 `build-work` mount cleanup --- implementation update

-   [x] **IMPLEMENTED in bootstrap r45:** The installed/final `pkgmk`
    work directory is now `/var/cache/pkg/build-work/pkgmk-$name`, a
    removable child directory beneath the bind mount, rather than the
    bind-mount root `/var/cache/pkg/build-work`.
-   This prevents pkgmk cleanup from attempting to remove the active
    mount point and producing `Device or resource busy`.
-   [x] The bootstrap unmount helper now returns a real error if a busy
    bootstrap mount cannot be unmounted instead of repeatedly retrying
    forever.
-   [ ] **Regression test:** Run Stage 3 and confirm no
    `rm: cannot remove '/var/cache/pkg/build-work': Device or resource busy`
    warning appears and all bootstrap mounts are gone afterward.

### Bootstrap Stage 3 `build-work` mount cleanup

-   [x] **FIX IMPLEMENTED in bootstrap r45; regression test pending:**
    During Stage 3, `pkgmk` emitted
    `rm: cannot remove '/var/cache/pkg/build-work': Device or resource busy`,
    but the package build continued.
-   Investigation confirmed `/tmp/lfs-rootfs/var/cache/pkg/build-work`
    is an active overlay-backed mount sourced from the live
    environment/project `build-work` path.
-   This is separate from the locale fixes and was not caused by
    changing `LC_ALL`/`LANG`.
-   Do not unmount the work directory while a package is actively
    building.
-   Review the bootstrap Stage 3 mount/setup and cleanup logic after the
    current build completes.
-   If the `build-work` mount is intentional, cleanup must remove/clean
    the contents safely without attempting to `rm` the active mount
    point itself.
-   Ensure cleanup unmounts the work directory at the appropriate
    end-of-stage/exit path before attempting to remove the mount-point
    directory.
-   Verify normal completion, failure, interruption, and rerun paths do
    not leave stale `build-work` mounts behind.
-   [ ] **Regression test:** On the next clean Stage 3 run, confirm
    there are no `Device or resource busy` cleanup messages and no stale
    `build-work` mount remains after Stage 3 exits.

### Bootstrap locale warning root cause and fixes

-   [x] **COMPLETED / ROOT CAUSE IDENTIFIED:** Repeated Stage 3 locale
    warnings were traced to explicit UTF-8 locale overrides rather than
    random bootstrap behavior.
-   Upstream `pkgutils 5.40.12` sets `LC_ALL=C.UTF-8` in `pkgmk.in`
    (`pkgmk`), which is unsafe during early BFSOS bootstrap phases
    because `C.UTF-8` is not guaranteed to exist yet.
-   The running temporary-toolchain copy of `pkgmk` was corrected from
    `LC_ALL=C.UTF-8` to `LC_ALL=C`.
-   The BFSOS `ports/core/pkgutils/Pkgfile` was updated so
    `bootstrap_build()` patches upstream `pkgmk.in` to use `LC_ALL=C`
    before installing the temporary-toolchain copy.
-   The same pkgutils port also patches the packaged `/usr/bin/pkgmk` in
    `post_build()` so the installed BFSOS pkgutils package consistently
    uses the universally available `C` locale.
-   The GCC port was also found to force `LANG=en_US.UTF-8`;
    `ports/core/gcc/Pkgfile` was changed to use `LANG=C` for
    bootstrap/build consistency.
-   Keep the global bootstrap environment on `LANG=C`, `LC_ALL=C`, and
    `LANGUAGE=C`.
-   [ ] **Verification pending on next clean bootstrap/RC run:** confirm
    Stage 1/2/3 no longer produce the previous flood of
    `setlocale: LC_ALL: cannot change locale (C.UTF-8)` warnings.
-   If isolated locale warnings remain after a clean rebuild, capture
    the exact package/log and investigate only that package rather than
    changing the global locale policy again.
-   These locale fixes should be pushed to both the main BFSOS project
    and the separate ports repository so the bootstrap and port trees
    remain consistent.

### Bootstrap Stage 3 locale regression check

-   [ ] During the next clean Stage 3 rebuild, verify that `pkgmk`, GCC,
    and shell subprocesses inherit plain `C` and that no build-generated
    environment reintroduces `C.UTF-8` or `en_US.UTF-8`.
-   Check the newly installed temporary-toolchain `pkgmk` with
    `grep -nE 'LC_ALL|LANG' .../pkgmk` as a regression check after
    pkgutils is rebuilt.

### Bootstrap Stage 3 time synchronization

-   [x] **FIX IMPLEMENTED in bootstrap r45; regression test pending:**
    Remove the redundant time synchronization step from Bootstrap Stage
    3.
-   Time is already synchronized when `bootstrap.sh` is initially
    launched, so Stage 3 should not perform another automatic time sync
    before rebuilding the base system with the final toolchain.
-   Preserve the initial bootstrap startup time synchronization; this
    change applies specifically to the extra Stage 3 sync.

### Pre-1.0 optional software and console usability checks

-   [x] **IMPLEMENTED in current installer/ports tree; runtime
    regression pending:** GPM is available as an optional package
    (`ports/opt/gpm`) and the installed-system configuration enables
    `gpm.service` when selected.

-   Check whether a `gpm` port already exists in the BFSOS ports tree.
    If it does not, create and validate a proper GPM port.

-   Add **GPM console mouse support** to the installer Optional Software
    menu.

-   If selected, install GPM and enable/configure the appropriate
    systemd service so console mouse selection/paste works on a real
    text console.

-   Verify that leaving GPM unselected does not alter the default
    install.

-   [ ] **Bare-metal verification of installer console text-size options
    before BFSOS 1.0.**

-   Verify all existing console font/text-size choices on a real Linux
    virtual console, not only through QEMU/SPICE or SSH.

-   Confirm that selecting each size changes the installer console
    immediately and that returning to **Default** restores the expected
    normal size.

-   Verify the selected persistent font is written correctly to
    `/etc/vconsole.conf`.

-   After first boot, verify `systemd-vconsole-setup` applies the
    selected font correctly.

-   Confirm the requested font files actually exist in the base system
    and that any fallback behavior is sensible and visible rather than
    silently masking a missing font.

-   Treat broken/nonfunctional text-size selection as a pre-1.0
    installer usability bug.

### Bootstrap Stage 2 completion return behavior

-   [x] **FIX IMPLEMENTED in bootstrap r45; regression test pending:**
    Remove the extra terminal completion/pause screen shown after
    Bootstrap Stage 2 completes successfully.
-   Current behavior displays:
    -   `Operation completed successfully.`
    -   `Press Enter to return to the menu...`
-   After a successful Stage 2 completion, return directly to the
    **Bootstrap main menu** instead of requiring an extra Enter
    keypress.
-   Keep actual Stage 2 success/failure status visible in the Bootstrap
    menu itself.
-   Do not remove or suppress real error dialogs/messages; this change
    applies only to the redundant success/pause screen after a
    successful Stage 2 run.

### BFSOS 1.0 public-release documentation and post-1.0 installer UX roadmap

-   [ ] **1.0 release/public launch preparation:** After the 1.0
    release-candidate storage/RAID/configuration validation is complete
    and no release-blocking core issues remain, clean up and rewrite the
    public `README.md` and supporting documentation for the BFSOS 1.0
    release.
-   The 1.0 README/docs should clearly explain what BFSOS is, current
    release/stability status, supported architecture, supported
    installation/storage configurations, build/install workflow, known
    limitations, where logs are stored, and how users should report
    useful bugs/issues.
-   Clearly distinguish the **core BFSOS system** from the broader
    **non-core ports collection**, which will continue to receive
    cleanup and tooling work after core 1.0 validation.
-   After BFSOS 1.0 final is published with polished documentation and
    usable release/install artifacts, consider/prepare a **DistroWatch
    submission** to bring additional testers and users to the project.
-   Wider public exposure is intended to provide more real-world
    hardware/configuration coverage and additional bug reports, but
    should follow---not precede---the 1.0 RC validation cycle.

#### Post-1.0 / target 1.1 timezone and locale selector improvements

-   [ ] **Post-1.0 enhancement (target 1.1):** Replace or enhance the
    current timezone prompt with a Dialog-driven hierarchical/scrollable
    selector.
-   Timezone selection should allow the user to choose a region first
    (for example `America`, `Europe`, `Asia`) and then move
    through/select the appropriate city/location from a list.
-   Provide consistent **Back**, **Select/Continue**, keyboard
    navigation, and text-mode fallback behavior matching the rest of the
    installer.
-   [ ] **Post-1.0 enhancement (target 1.1):** Replace or enhance locale
    selection with a scrollable Dialog checklist/radiolist based on
    available locales.
-   Keep `en_US.UTF-8` as the normal/default user locale unless the user
    chooses another locale.
-   Allow additional locales to be selected/generated when desired,
    while allowing the system default `LANG` to be chosen separately.
-   **The `C` locale must always remain available and must not be
    removable/disableable by the locale-selection UI.**
-   Preserve use of the `C` locale for bootstrap/build operations where
    deterministic output or operation before the full locale environment
    exists is desirable.
-   These timezone/locale UI improvements are **not BFSOS 1.0 release
    blockers** unless the existing selectors prove functionally broken
    during RC testing. Avoid adding unnecessary installer feature risk
    immediately before 1.0 final.
-   These are installer usability improvements suitable for the **1.x
    series (preferably 1.1)** rather than requiring a 2.0 release.

#### Post-1.0 ZFS support roadmap

-   [ ] **Post-1.0 enhancement:** Add OpenZFS/ZFS support to BFSOS after
    the 1.0 release rather than expanding the pre-1.0 storage regression
    matrix.
-   Start with **ZFS for non-root/data storage**: package the OpenZFS
    userland and kernel module cleanly, verify pool create/import/export
    and boot-time import, and integrate the required module/initramfs
    handling.
-   Validate OpenZFS compatibility against BFSOS-supported kernels,
    including the planned Linux 6.18 LTS line, and define a maintainable
    policy for kernel/OpenZFS version compatibility before enabling it
    by default.
-   Keep existing MD/Linear/JBOD, LUKS, LVM, Btrfs, F2FS, ext\*, and XFS
    behavior unchanged while ZFS support is introduced.
-   Treat **root-on-ZFS as a later phase** after non-root ZFS support is
    stable; root-on-ZFS requires dedicated installer, initramfs,
    bootloader, pool-import, rollback/recovery, and upgrade regression
    testing.
-   Document OpenZFS licensing/distribution considerations and any
    external-module rebuild requirements so kernel upgrades cannot
    silently leave a ZFS installation unbootable or without its pools.
-   This is **not a BFSOS 1.0 release blocker**.

### BFSOS 1.0-rc1 release-candidate milestone

-   [ ] **POTENTIAL 1.0-rc1 CANDIDATE:** If the current bare-metal
    bootstrap/install completes successfully and the resulting BFSOS
    system boots correctly without a new release-blocking core issue,
    treat this build line as the first **BFSOS 1.0-rc1** candidate.
-   The immediate release-candidate priority is validation of the **core
    operating system, bootstrap, installer, boot path, storage layouts,
    RAID combinations, encryption/LVM/Btrfs configurations, and other
    supported installation scenarios**.
-   Over the next several days, test the remaining
    RAID/storage/configuration combinations and correct any
    core/bootstrap/installer/boot regressions discovered during those
    tests.
-   A failure of the current installation to boot is considered a
    **release-candidate blocker** and must be fixed and retested before
    promoting the build to 1.0-rc1 status.
-   Minor/non-blocking tracker cleanup can continue through the 1.0
    release-candidate cycle while the supported installation
    configurations are validated.
-   **Non-core ports are not a 1.0-rc1/core release blocker at this
    stage.** The broader non-core ports tree is known to need
    substantial cleanup and should be handled after the 1.0 RCs have
    established that the core OS and supported installation/storage
    configurations are reliable.
-   After the RAID/configuration matrix is verified through the 1.0 RC
    cycle and no release-blocking core issues remain, target the final
    **BFSOS 1.0** release.
-   Following core 1.0 validation, shift development emphasis toward
    repairing/maintaining the non-core ports collection and developing
    better **ports management, validation, update, and maintenance
    tooling**.

### Bootstrap time synchronization behavior

-   [x] **COMPLETED / VERIFIED:** Synchronize system time once when
    `bootstrap.sh` starts.
-   Do **not** redundantly synchronize time again before Bootstrap Stage
    2 when continuing in the same running bootstrap session.
-   If the machine is rebooted or a new bootstrap session is started,
    launching `bootstrap.sh` performs the startup time synchronization
    again.
-   This keeps Stage 2 from doing unnecessary duplicate time-sync work
    while still ensuring a fresh bootstrap session begins with a
    corrected clock.

### Bootstrap Stage 1 toolchain archive compression output

-   [x] **FIX IMPLEMENTED in bootstrap r45; regression test pending:**
    After Bootstrap Stage 1 verification succeeds, hide/suppress the
    verbose toolchain archive compression output during normal
    interactive use.
-   The user does not need to watch the full compression file/progress
    stream after verification has already completed successfully.
-   Show a concise status such as **Compressing toolchain archive...**
    while the archive is being created, then report the completed
    archive path/size or a clear error if compression fails.
-   Preserve detailed compression output in the appropriate bootstrap
    log for troubleshooting rather than filling the interactive
    terminal/menu.

### Bootstrap Stage 1 download-failure recovery regression

-   [x] **FAILURE CAPTURE HARDENED in r74 code; intentional
    failed-download regression pending:** Stage 1 now invokes `pkgmk` in
    an explicit conditional status path so its nonzero result can return
    to the existing Bootstrap failure-dialog/menu boundary instead of
    being treated as an uncaught shell failure.
-   **Observed behavior:** A Stage 1 source download failed after three
    attempts; when the final download attempt failed, the Bootstrap UI
    closed and returned the user to the shell.
-   **Required behavior:** Catch the Stage 1 `pkgmk` nonzero status at
    the parent/menu boundary. When Dialog mode is available, display the
    standard failure dialog with the package/operation, failed URL when
    detectable, exit status, and preserved log path.
-   **Navigation requirement:** Selecting **Continue** must return
    directly to the Bootstrap main menu without terminating
    `bootstrap.sh`.
-   **State preservation:** Preserve all successfully completed Stage 1
    package markers/toolchain state so the user can repair the
    source/port and resume Stage 1 without rebuilding completed
    packages.
-   **Audit target:** Check the Stage 1 parent call chain for `set -e`
    or other uncaught nonzero-status propagation that bypasses the
    existing failure-handler code.
-   **Regression test:** Intentionally use an invalid Stage 1 source
    URL, allow all configured download retries to fail, verify the
    failure Dialog appears, select Continue, verify the Bootstrap main
    menu remains alive, repair the URL, and confirm Stage 1 resumes from
    the failed/incomplete package.

### Download/package failure messaging in bootstrap and installer

-   [x] **IMPLEMENTATION UPDATED in Bootstrap + installer r46;
    regression tests still required:** download/package operations now
    use explicit status capture at the critical Stage 1 and
    installed-system package boundaries, preserve failure context, and
    return through their parent UI/retry paths.
-   **Observed bootstrap failure:** MPC source download returned HTTP
    404 and `pkgmk` exited with status 4. Bootstrap Stage 1 terminated
    without a clear menu-level explanation, while Bootstrap Stage 2
    later displayed the raw error text but still did not use the normal
    dialog/menu workflow.
-   **Bootstrap requirement:** Catch source/download/build failures and
    show a **dialog error box** when Dialog mode is available. The
    dialog should identify the package or operation, show the failed URL
    when known, summarize the underlying downloader/build error, include
    the exit status, and show the preserved package log path.
-   **Bootstrap navigation:** The failure dialog should have a
    **Continue** button. Selecting Continue must return the user
    directly to the **Bootstrap main menu** without exiting
    `bootstrap.sh`.
-   **Installer review:** The installer currently invokes `ports -u`,
    `prt-get sysup`, and `prt-get depinst` directly inside a
    strict-error shell path. A download/build failure from those
    commands can therefore abort the installation path without
    installer-specific UI/context unless explicitly caught.
-   **Installer requirement:** Catch ports synchronization, mandatory
    upgrade, and optional package-install failures and show a **dialog
    error box** with the failed operation/package when known, failed URL
    when available, useful underlying output, exit status, and installer
    log path. Preserve the installer log before cleanup.
-   **Installer navigation:** The failure dialog should have a
    **Continue** button. Selecting Continue must return the user to the
    **installer main menu/configuration screen**, not terminate the
    installer or dump directly to the shell.
-   **Text-mode fallback:** If Dialog is unavailable, print the same
    failure details in text mode, prompt **Press Enter to continue**,
    then return to the respective main menu.
-   **Do not hide the real error:** The dialog should summarize the
    failure, but the full raw downloader/build output must remain in the
    corresponding log for troubleshooting.
-   **Regression tests:** Deliberately use a bad source URL once in
    Bootstrap Stage 1, once in Bootstrap Stage 2, and once during
    installer package installation. In all cases verify the error is
    shown in the appropriate dialog/text fallback, the log path is
    visible, and Continue returns to the correct main menu without
    terminating the parent workflow.

### pkgmk source URL fallback / backup mirrors

-   \[\~\] **PARTIAL IMPLEMENTATION UPDATED (2026-08-18):** The 29 core
    GNU Pkgfiles use canonical `https://ftp.gnu.org/gnu/...` paths.
    pkgutils release 11 now removes the noisy third-party flat mirror
    and hardens resumable/retry behavior for direct sources.
    Path-preserving automatic GNU host fallback (`ftp.gnu.org/gnu` -\>
    `mirrors.kernel.org/gnu`) is still pending because CRUX
    `PKGMK_SOURCE_MIRRORS` is intentionally flat.
-   **r74 remaining work:** The current pkgmk mirror mechanism is
    filename/flat-cache based; the requested `mirrors.kernel.org/gnu`
    alternate host requires path-preserving URL substitution. Do not
    claim full completion merely by adding unused variables to
    `pkgmk.conf`.
-   **Goal:** A slow, unreachable, or failed primary source must not
    force the user to wait through repeated retries when a known-good
    alternate source exists.
-   **GNU source policy:** For GNU-hosted distfiles, preserve the
    original package path and support ordered alternate hosts. Current
    candidates tested successfully with `autoconf-2.73.tar.xz` are
    `https://ftp.gnu.org/gnu/` and `https://mirrors.kernel.org/gnu/`.
    Avoid relying on `ftpmirror.gnu.org` as the only source because its
    redirect/mirror selection can stall for a long time at 0 bytes.
-   **Path-aware fallback required:** GNU mirrors are hierarchical, not
    flat distfile caches. The fallback implementation must preserve
    paths such as `autoconf/autoconf-$version.tar.xz`,
    `glibc/glibc-$version.tar.xz`, and
    `gcc/gcc-$version/gcc-$version.tar.xz` rather than simply appending
    the filename to a mirror root.
-   **Centralized behavior:** Prefer implementing host/path substitution
    or equivalent fallback handling in BFSOS `pkgmk`/its extension so
    individual Pkgfiles do not need duplicate source URLs solely for
    mirror redundancy.
-   **Configuration consistency:** Any generated bootstrap `pkgmk.conf`
    must inherit the same ordered backup-source policy as the final
    packaged/default configuration so Stage 1, Stage 2, Stage 3,
    installer package operations, and the installed system behave
    consistently.
-   **Do not restore the removed FreeBSD distcache fallback:** The
    previous `distcache.FreeBSD.org/ports-distfiles/` fallback was
    removed after producing incorrect/unreliable behavior and must not
    be reintroduced.
-   **Retry interaction:** Keep per-URL connection/retry limits short
    enough that `pkgmk` can advance to the next alternate source
    promptly rather than spending minutes retrying one dead or stalled
    endpoint.
-   **Integrity:** Existing source checksum/signature verification
    remains authoritative regardless of which alternate URL supplied the
    distfile.
-   **Regression test:** Deliberately make the primary GNU source
    unreachable; verify `pkgmk` advances to the next configured URL
    automatically, downloads the identical distfile, passes the normal
    integrity checks, and completes the package build. Repeat in Stage 1
    and in the installed/final `pkgmk` environment.

### Bootstrap Stage 3 availability status

-   [x] **COMPLETED / VERIFIED:** Correct Stage 3
    (`Rebuild base system with final toolchain`) status logic.
-   Stage 3 now shows **\[PENDING\]** until the required
    temporary-toolchain/base-system prerequisite stages are complete.
-   After Stage 2 is complete, Stage 3 changes to **\[AVAILABLE\]**.
-   After Stage 3 itself is completed, it shows **\[COMPLETE\]**.
-   Corrected in both the dialog and text-fallback bootstrap menus.
-   Verified during testing on August 11, 2026: the corrected behavior
    now appears as intended.

**Installer:** `install-bfs-menu-v50-luks-auto-cryptsetup.sh`\
**Test focus:** RAID + LUKS + LVM\
**Status:** Active testing

## Issues Found

### 1. RAID selection summary is plain text instead of Dialog

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** RAID creation / RAID type summary
-   **Current behavior:** After choosing a RAID type, the installer
    drops out of the Dialog UI and prints a text summary in the
    terminal.
-   **Observed output:**

``` text
# RAID selection summary

RAID type     : RAID 5
Minimum disks : 3
Layout        : Striping with distributed parity
Redundancy    : One drive may fail
Performance   : Fast reads; good general-purpose writes
Usable space  : Capacity of N-1 members

Press Enter to continue...
```

-   **Desired behavior:** Display this information in a Dialog
    `--msgbox` (or equivalent) and return cleanly to the Dialog
    workflow.
-   **Priority:** UI cleanup
-   **Regression test:** Select each supported RAID level and verify its
    summary appears inside Dialog without dropping back to the terminal.

### 4. RAID creation result/progress is plain text instead of Dialog

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** RAID creation / post-create status
-   **Current behavior:** After `mdadm` starts the array, the installer
    drops to plain terminal output showing `/proc/mdstat`, recovery
    percentage, estimated completion time, and
    `Press Enter to continue...`.
-   **Observed example:**

``` text
mdadm: array /dev/md0 started.

Personalities : [raid4] [raid5] [raid6]
md0 : active raid5 ...
      [>....................]  recovery = 0.0% ...
      bitmap: 2/2 pages [8KB], 65536KB chunk

Press Enter to continue...
```

-   **Desired behavior:** Keep the user in Dialog. Show array creation
    success and status in a Dialog `--msgbox`; optionally use a Dialog
    `--gauge` if the installer chooses to monitor initial RAID
    recovery/sync progress.
-   **Priority:** UI cleanup
-   **Regression test:** Create RAID5 and verify the post-create status
    never drops back to the terminal UI.

### 5. LUKS device selection is plain text and dumps full `lsblk` output

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** LUKS creation / encrypted-device selection
-   **Current behavior:** Choosing "Create a new LUKS container" prints
    a full `lsblk -fp` style device tree to the terminal, including loop
    devices, optical media, whole disks, mounted build storage, RAID
    members, and the assembled MD array, then asks
    `Block device to encrypt:` as a raw text prompt.
-   **Observed behavior:** The terminal shows `/dev/loop0`, `/dev/sr0`,
    `/dev/vda*`, `/dev/vdb1`-`/dev/vdf1`, `/dev/md0`, and `/dev/vdg`,
    followed by:

``` text
Block device to encrypt:
```

-   **Desired behavior:** Use a Dialog selection list for LUKS targets.
    Show only sensible encryptable block-device candidates, with device
    path, size, type, and current filesystem/signature. Exclude loop
    devices, optical media, mounted installer/build media, whole disks
    when a child partition is the intended unit, and RAID member
    partitions that are already claimed by an active MD array. The
    assembled `/dev/md0` should be selectable for the RAID -\> LUKS -\>
    LVM test.
-   **Priority:** UI + safety cleanup
-   **Regression test:** Enter the LUKS create flow with an active RAID
    array and verify `/dev/md0` is offered while
    `/dev/vdb1`-`/dev/vdf1`, `/dev/loop0`, `/dev/sr0`, and `/dev/vdg`
    are not offered as accidental targets.

### 6. `cryptsetup luksFormat` destructive confirmation is raw terminal input

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** LUKS creation / destructive confirmation
-   **Current behavior:** `cryptsetup luksFormat` exposes its native
    terminal warning and requires the user to type the exact
    confirmation text:

``` text
WARNING!
This will overwrite data on /dev/md0 irrevocably.

Are you sure? (Type 'yes' in capital letters):
```

-   **Desired behavior:** The installer should present its own clear
    Dialog `--yesno` destructive-action warning before invoking
    `cryptsetup`. After explicit confirmation, invoke cryptsetup in a
    non-interactive/force-confirmed mode where supported so its native
    typed confirmation does not break the Dialog workflow.
    Password/passphrase entry should remain secure and must not be
    exposed on the command line.
-   **Priority:** UI + safety cleanup
-   **Regression test:** Create a LUKS container and verify the
    destructive confirmation occurs entirely through Dialog, Cancel/No
    safely returns without formatting, and no plaintext passphrase
    appears in process arguments or logs.

### 7. LUKS mapping-name prompt is plain text

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** LUKS creation / opening newly created container
-   **Current behavior:** After creating a LUKS container, the installer
    asks `Mapping name to open now [leave blank to skip]:` using a raw
    terminal prompt.
-   **Desired behavior:** Use a Dialog `--inputbox`, with clear guidance
    that this creates `/dev/mapper/<name>`, plus a Cancel/Skip path.
    Consider suggesting a sensible default based on intended use (for
    example `cryptroot` for `/` and `cryptraid` for an encrypted RAID
    device).
-   **Priority:** UI cleanup
-   **Regression test:** Create LUKS on a partition and on an MD array;
    verify mapping-name entry, skip, and cancel all remain in Dialog and
    produce the expected mapper device.

### 8. LUKS mapping name should be required

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** LUKS creation / mapper naming
-   **Current behavior:** The mapping-name prompt allows a blank value
    to skip opening the newly created LUKS container.
-   **Desired behavior:** Require a valid mapping name when creating a
    LUKS container through the installer. Do not allow an empty name.
    Re-prompt on blank or invalid input and explain that the resulting
    device will be `/dev/mapper/<name>`. Provide sensible suggested
    defaults such as `cryptroot` for an encrypted root partition and
    `cryptraid` for an encrypted RAID device.
-   **Validation:** Reject whitespace, `/`, and names that would
    conflict with an existing `/dev/mapper` mapping. Keep an explicit
    Cancel/Back action separate from an empty mapping name.
-   **Priority:** Workflow + UI cleanup
-   **Regression test:** Verify blank and invalid names are rejected,
    existing mapper names cannot be reused accidentally, and a valid
    name opens the LUKS device successfully.

### 9. LUKS passphrase entry and post-open pause drop to plain terminal UI

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** LUKS creation/opening / passphrase and completion
-   **Current behavior:** The LUKS passphrase is requested using the raw
    `cryptsetup` terminal prompt, and after the operation the installer
    uses a plain `Press Enter to continue...` pause.
-   **Desired behavior:** Keep the workflow in Dialog. Use a secure
    Dialog password box for passphrase entry and confirmation, then feed
    the passphrase to `cryptsetup` without exposing it in command-line
    arguments, logs, shell tracing, or temporary plaintext files.
    Replace the terminal `Press Enter to continue...` with a Dialog
    success/status message.
-   **Safety:** Never echo the passphrase. Ensure installer
    logging/xtrace cannot capture it. Clear shell variables containing
    the passphrase as soon as practical.
-   **Priority:** UI + security cleanup
-   **Regression test:** Create and open LUKS successfully from Dialog;
    verify passphrase is hidden, confirmation mismatch is handled
    cleanly, no passphrase appears in logs/process arguments, and
    completion returns through Dialog.

### 10. Newly created LUKS containers are not remaining open

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** LUKS creation / mapper activation
-   **Current behavior:** After creating LUKS containers, `lsblk`
    correctly shows `crypto_LUKS` on `/dev/vda4` and `/dev/md0`, but the
    expected mapper devices are inactive (`cryptsetup status cryptraid`
    and `cryptsetup status luksroot` report inactive).
-   **Desired behavior:** When the installer requires a mapping name
    during LUKS creation, successfully open the new container
    immediately and verify `/dev/mapper/<name>` exists before returning
    to the storage menu. If opening fails, show a Dialog error and
    remain in the LUKS workflow rather than silently continuing.
-   **Validation:** After `cryptsetup open`, verify
    `cryptsetup status <name>` is active and
    `test -b /dev/mapper/<name>` succeeds.
-   **Priority:** Functional LUKS workflow bug
-   **Regression test:** Create LUKS on a normal partition and on an MD
    array; both mappings must remain active and be selectable by the
    filesystem/LVM setup screens until installer cleanup or an explicit
    Close action.

### 11. LVM physical-volume selection should be a Dialog device selector

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** LVM setup / physical-volume creation
-   **Current behavior:** The installer asks the user to type a
    block-device path manually when creating an LVM physical volume.
-   **Desired behavior:** Present eligible devices in a Dialog
    menu/checklist navigable with Up/Down and selectable with
    Space/Enter as appropriate. Show useful metadata such as device
    path, size, type, and current filesystem/signature.
-   **Filtering/safety:** Include valid devices and active mapper
    devices such as `/dev/mapper/cryptraid`; exclude loop/optical
    devices, mounted installer media, active RAID member partitions, and
    devices already consumed by another storage layer unless explicitly
    appropriate.
-   **Selection model:** Support selecting one or more PV devices if the
    installer supports multi-PV volume groups. Provide Back/Cancel
    without terminating the installer.
-   **Priority:** UI + safety cleanup
-   **Regression test:** With RAID -\> LUKS active, verify
    `/dev/mapper/cryptraid` appears as an eligible PV and can be
    selected entirely through Dialog without manually typing its path.

### 12. LVM operation success messages use plain `Press Enter to continue...`

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** LVM setup / post-operation feedback
-   **Current behavior:** After successful LVM operations, such as
    creating logical volume `var`, the installer drops to terminal text:

``` text
Logical volume "var" created.

Press Enter to continue...
```

-   **Desired behavior:** Replace terminal pauses after successful
    PV/VG/LV operations with Dialog `--msgbox` success messages and
    return directly to the appropriate LVM Dialog menu.
-   **Priority:** UI cleanup
-   **Regression test:** Create PVs, a VG, and multiple LVs and verify
    every success/failure result remains in Dialog with no raw
    `Press Enter to continue...` screens.

### 13. LVM status/summary output is plain terminal text

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** LVM setup / status summary
-   **Current behavior:** The installer prints raw `pvs`, `vgs`, and
    `lvs` output to the terminal, followed by
    `Press Enter to continue...`.
-   **Observed example:** PV `/dev/mapper/cryptraid`, VG `bfs-vg`, and
    LVs `home` and `var` are shown using the native LVM table output.
-   **Desired behavior:** Render a concise LVM summary inside Dialog,
    ideally using a `--textbox`, `--msgbox`, or formatted
    menu/table-style screen. Show PV, VG, LV names, sizes, and free
    space while keeping the user inside the Dialog workflow.
-   **Priority:** UI cleanup
-   **Regression test:** Open the LVM status/review screen after
    creating PV/VG/LVs and verify no raw terminal table or
    `Press Enter to continue...` prompt appears.

### 14. Filesystem selector should hide LUKS backing devices when their decrypted layer is in use

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** Filesystem device selection / storage-layer filtering
-   **Current behavior:** The filesystem selector still offers
    `/dev/md0` and `/dev/vda4` even though both contain active LUKS
    containers. Selecting or formatting either backing device would
    overwrite the encryption layer.
-   **Desired behavior:** When a block device has a LUKS container and
    its decrypted mapper is active or consumed by another storage layer,
    hide the encrypted backing device from normal
    filesystem-format/mount selection. Show only the usable top-level
    devices, such as `/dev/mapper/luksroot` and LVs built on
    `/dev/mapper/cryptraid`.
-   **Safety:** Do not allow accidental filesystem formatting of an
    active LUKS backing device. If an advanced workflow ever exposes it,
    mark it clearly as `LUKS backing device — do not format` and require
    an explicit destructive override.
-   **Priority:** Safety + UI cleanup
-   **Regression test:** With LUKS on `/dev/vda4` and `/dev/md0`, verify
    neither backing device appears as a normal filesystem target while
    their decrypted/derived devices are active.

### 15. Remove plain `Press Enter to continue...` after filesystem selection

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** Filesystem selection / transition to next installer stage
-   **Current behavior:** After all filesystem targets and mount points
    have been selected, the installer drops to a raw
    `Press Enter to continue...` prompt.
-   **Desired behavior:** Prefer no extra pause at all: once filesystem
    selection is complete and validated, proceed directly to the next
    installer stage. If user confirmation is needed before
    formatting/mounting, use a Dialog summary/confirmation screen
    instead of a terminal pause.
-   **Priority:** UI/workflow cleanup
-   **Regression test:** Complete filesystem assignments and verify the
    installer either advances directly or displays a meaningful Dialog
    confirmation; no raw Enter prompt should appear.

### 16. Remove plain pause after base archive stage

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** Base archive / transition to next installer stage
-   **Current behavior:** After the base archive operation completes,
    the installer stops at a raw `Press Enter to continue...` prompt.
-   **Desired behavior:** On successful completion, continue
    automatically to the next installer stage. Do not add a Dialog
    message merely to replace an unnecessary terminal pause. Use Dialog
    only when there is meaningful information, a warning, an error, or a
    decision the user needs to make.
-   **Priority:** UI/workflow cleanup
-   **Regression test:** Complete the base archive stage successfully
    and verify the installer advances automatically with no raw Enter
    prompt or redundant OK dialog.

### 17. Installation summary incorrectly reports no encrypted devices

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** Final installation review / LUKS summary
-   **Current behavior:** The BFS Installation summary reports
    `LUKS Encryption: Enabled YES` but `Encrypted devices: no`, even
    though this test has LUKS containers on `/dev/vda4` (opened as
    `/dev/mapper/luksroot`) and `/dev/md0` (opened as
    `/dev/mapper/cryptraid`, then used by LVM).
-   **Desired behavior:** Detect and list the actual encrypted backing
    devices and mapper names in the final review, including LUKS devices
    that are underneath LVM/RAID layers.
-   **Expected example:** `/dev/vda4 -> luksroot` and
    `/dev/md0 -> cryptraid`.
-   **Priority:** Functional review/reporting bug
-   **Regression test:** Build RAID5 -\> LUKS -\> LVM plus a separate
    LUKS root and verify the final review reports both encrypted devices
    and their mappings rather than `no`. \### 18. Remove raw
    `Press Enter to continue...` before BFS Installation summary
-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** Transition into final installation review
-   **Current behavior:** A raw terminal `Press Enter to continue...`
    appears before the BFS Installation summary.
-   **Desired behavior:** Continue directly into the Dialog review
    screen unless an actual user decision is required.
-   **Priority:** UI/workflow cleanup

### 19. Fatal crypttab generation failure with existing/reopened LUKS mappings

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed.sh`
-   **Area:** LUKS detection / `/etc/crypttab` generation
-   **Current behavior:** The installer correctly detects that encrypted
    storage is present, but `generate_crypttab()` produces zero records
    and aborts with:

``` text
ERROR: Encrypted storage was detected, but no crypttab entries could be generated.
```

-   **Test topology:** `/dev/vda4 -> luksroot -> /` and
    `/dev/md0 -> cryptraid -> LVM -> home/var`.
-   **Likely failure point to verify:** `crypt_mapping_records()`
    discovers `crypt` nodes through `lsblk`, then relies on
    `lsblk ... PKNAME` to derive the encrypted backing device.
    Existing/reopened device-mapper stacks may not be represented the
    way this code expects.
-   **Desired behavior:** Discover active LUKS mappings from the actual
    block-device topology regardless of whether they were created in the
    current installer process or opened before restarting the installer.
    Generate entries for both root and encrypted RAID mappings.
-   **Expected crypttab mappings:** `luksroot` backed by the LUKS UUID
    of `/dev/vda4`; `cryptraid` backed by the LUKS UUID of `/dev/md0`.
-   **Priority:** Critical functional blocker
-   **Regression test:** Restart installer with pre-opened LUKS
    mappings, select filesystems on mapper/LVM descendants, and verify
    `/etc/crypttab` is generated correctly without relying on
    current-session LUKS state.

### 20. Base archive path prompt is not using Dialog

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r2.sh`
-   **Area:** Base archive selection
-   **Current behavior:** The installer asks for the base/rootfs archive
    path using a plain terminal prompt rather than Dialog.
-   **Desired behavior:** Use a Dialog `--inputbox` (or a file/path
    selector if practical) with the detected/default base archive path
    pre-filled, so the user can accept or edit it without leaving the
    Dialog UI.
-   **Priority:** UI cleanup
-   **Regression test:** Reach base archive selection and verify the
    archive path is requested entirely through Dialog with the default
    path visible/editable.

### 21. Final installation review does not show configured RAID arrays

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r4.sh`
-   **r4 correction:** The earlier `/proc/mdstat` parser checked the
    wrong field (`$2 ~ /^raid/`) for lines shaped like
    `md0 : active raid5 ...`, causing `RAID enabled: YES` but an array
    list of `none`. r4 parses the actual MD status line correctly and
    reports the live array.
-   **Area:** Final installation review / RAID summary
-   **Current behavior:** The final review omits the configured software
    RAID array(s), so the storage summary does not show the RAID layer
    even when `/dev/md0` is part of the installation topology.
-   **Desired behavior:** Add a RAID section to the review showing each
    array device, RAID level, member devices, size, and current state.
    For this test topology it should show `/dev/md0`, RAID5, and members
    `/dev/vdb1 /dev/vdc1 /dev/vdd1 /dev/vde1 /dev/vdf1`.
-   **Detection:** Derive the review from actual active MD state
    (`/proc/mdstat`/`mdadm --detail`) rather than only installer-session
    variables, so restarted/resumed installs are reported correctly.
-   **Priority:** Review/reporting correctness
-   **Regression test:** Restart the installer with an existing active
    RAID5 and verify the final review still lists the array, level, and
    members.

### 22. Filesystem and mount-point assignment needs a single multi-entry Dialog workflow

-   [x] Partial workflow fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r2.sh`
-   **Note:** Replaced the repeated `Add another?` prompt with a
    persistent selector and explicit `Done selecting filesystems`
    action. A fuller Add/Edit/Remove planner can still be refined later
    if desired.
-   **Area:** Filesystem selection / mount-point assignment
-   **Current behavior:** The installer configures one filesystem/mount
    point at a time and repeatedly asks whether the user wants to add
    another partition/filesystem.
-   **Desired behavior:** Replace the repeated yes/no loop with a
    persistent Dialog assignment screen. The user should be able to move
    through eligible devices, add/edit/remove assignments, and see the
    complete filesystem plan before selecting `Done`.
-   **Suggested workflow:** Show eligible top-level devices in one menu;
    selecting a device opens its filesystem/format/mount-point options;
    return to the same assignment screen with the configured value
    displayed. Provide `Add/Edit`, `Remove`, `Back`, and `Done` actions
    rather than repeatedly asking `Add another?`.
-   **Safety:** Continue hiding consumed backing devices such as active
    LUKS parents and RAID member partitions. Clearly identify EFI, boot,
    swap, mapper devices, and LVs.
-   **Validation on Done:** Require exactly one `/`, reject duplicate
    mount points, validate EFI/boot choices where applicable, and show a
    final filesystem plan before destructive formatting.
-   **Priority:** Major UI/workflow improvement
-   **Regression test:** Configure `/`, `/boot`, `/boot/efi`, swap,
    `/home`, and `/var` without answering a repeated yes/no prompt after
    each assignment.

### 23. make-ca package conflicts with ca-certificates ownership

-   [x] Fix
-   **Implemented in:** `Pkgfile-make-ca-release4-fixed`
-   **Area:** Package installation / CA trust store
-   **Current behavior:** `make-ca 1.16.1-3` tries to install
    `etc/ssl/certs/ca-certificates.crt`, but that path is already owned
    by the installed `ca-certificates` package, causing `pkgadd` to
    abort.
-   **Confirmed owner:** `ca-certificates` owns
    `etc/ssl/certs/ca-certificates.crt`; current link is
    `/etc/ssl/certs/ca-certificates.crt -> /etc/ssl/cert.pem`.
-   **Desired behavior:** Do not have `make-ca` package own a path
    already owned by `ca-certificates`. Remove the compatibility symlink
    from the make-ca package and ensure the CA trust-store packages
    provide a consistent chain that httpup can use.
-   **Priority:** Critical packaging/install blocker
-   **Regression test:** Fresh install with both ca-certificates and
    make-ca must complete without file-ownership conflicts, and
    `ports -u` must succeed afterward.

### 24. Add intelligent default mount points during filesystem assignment

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r3.sh`
-   **Area:** Filesystem / mount-point assignment
-   **Current behavior:** Mount points must be entered manually even
    when the selected device name or filesystem makes the intended mount
    point obvious.
-   **Desired behavior:** Pre-fill a sensible mount-point suggestion
    while keeping it editable by the user.
-   **Suggested defaults:**
    -   LV named `home` -\> `/home`
    -   LV named `var` -\> `/var`
    -   LV named `root` -\> `/`
    -   dm-crypt mapping named `luksroot` -\> `/`
    -   `ext2` partition -\> `/boot` when `/boot` is not already
        assigned
    -   `vfat`/FAT32 partition -\> `/boot/efi` when `/boot/efi` is not
        already assigned
    -   swap -\> `swap`
-   **Safety:** Defaults are suggestions only. Do not overwrite an
    existing assignment or guess for generic Btrfs/ext4/XFS devices
    without a useful device/LV/mapping name.
-   **Priority:** Filesystem workflow improvement
-   **Regression test:** Selecting `bfs-vg/home`, `bfs-vg/var`,
    `/dev/vda2` ext2, `/dev/vda1` vfat, and `luksroot` should pre-fill
    `/home`, `/var`, `/boot`, `/boot/efi`, and `/` respectively.
    \### 25. Show complete filesystem plan in the final Yes/No
    confirmation
-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r3.sh`
-   **Area:** Filesystem assignment confirmation
-   **Current behavior:** The final confirmation page presents only
    Yes/No, so the user cannot verify what was selected before
    continuing.
-   **Desired behavior:** The confirmation Dialog must display the
    complete pending filesystem plan above the Yes/No choice.
-   **Display for each assignment:** device, filesystem, mount point,
    and whether it will be formatted/reformatted. Include swap
    explicitly.
-   **Example information:** `/dev/mapper/luksroot -> btrfs -> /`,
    `/dev/bfs-vg/home -> btrfs -> /home`,
    `/dev/bfs-vg/var -> btrfs -> /var`, `/dev/vda2 -> ext2 -> /boot`,
    `/dev/vda1 -> vfat -> /boot/efi`, `/dev/vda3 -> swap`.
-   **Behavior:** `Yes` accepts the displayed plan; `No` returns to the
    filesystem assignment screen so selections can be corrected rather
    than discarding the whole workflow.
-   **Priority:** Safety / usability
-   **Regression test:** Configure multiple filesystems and verify the
    final Yes/No Dialog visibly lists every selected device, filesystem,
    mount point, format choice, and swap before the user commits.

### 26. Convert "Show Current Storage Devices" to Dialog and remove Enter pause

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r3.sh`
-   **Area:** Storage menu / current-device display
-   **Current behavior:** `Show Current Storage Devices` dumps storage
    information to the terminal and then uses a raw
    `Press Enter to continue...` pause.
-   **Desired behavior:** Capture the storage-device output and display
    it in a scrollable Dialog window (`--textbox` or equivalent) with
    normal Dialog navigation such as OK/Back.
-   **Required cleanup:** Remove the terminal
    `Press Enter to continue...` prompt entirely. Closing the Dialog
    should return directly to the storage menu.
-   **Priority:** UI consistency
-   **Regression test:** Open `Show Current Storage Devices`; verify no
    raw terminal output or Enter pause appears. \### 27. Preselect git
    and wget in Optional Software
-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r3.sh`
-   **Area:** Optional Software Dialog
-   **Current behavior:** `git` and `wget` are not enabled by default.
-   **Desired behavior:** Show both `git` and `wget` as selected/on by
    default while still allowing the user to deselect either package.
-   **Priority:** Default-package usability
-   **Regression test:** Open Optional Software on a fresh installer run
    and verify both `git` and `wget` are initially checked.

### 28. Add save/load support for complete installer configuration profiles

-   \[\~\] Partial implementation
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r3.sh`
    (profile save/load UI, non-secret core settings, filesystem
    assignments, device validation)
-   **Remaining:** RAID/LUKS/LVM creation is currently imperative in
    v50, so a profile cannot yet safely recreate those layers from
    scratch. Finish this when storage setup is refactored into a
    declarative plan; never store LUKS passphrases.
-   **Area:** Installer configuration / main menu
-   **Goal:** Allow the user to save the current installer selections to
    a reusable configuration file and load a saved configuration on a
    later installer run.
-   **Save:** Store non-secret installer choices including hostname,
    timezone, locale, network configuration, users/user options, storage
    topology selections, RAID configuration, LUKS device/mapping
    choices, LVM configuration, filesystem and mount-point assignments,
    Btrfs/Snapper choices, optional software, base archive choice,
    bootloader/GRUB choices, and normal/fallback EFI installation
    choices.
-   **Load:** Populate installer state from the selected profile so the
    user does not need to answer every installer question again.
-   **Secrets:** Never store user/root passwords, LUKS passphrases,
    private keys, or other authentication secrets in the profile. Prompt
    for those normally when required.
-   **Validation:** Loading a profile must validate devices and other
    machine-specific values against the current system. Missing or
    changed devices must be clearly flagged and returned to the user for
    correction; never blindly perform destructive operations using stale
    device paths.
-   **Review:** A loaded profile must still pass through the normal
    installer review/confirmation screens before destructive actions or
    installation begin.
-   **UI:** Add Dialog options such as `Load configuration`,
    `Save current configuration`, and `Save configuration as...`.
-   **Format:** Use a documented, human-readable configuration format
    that can be inspected and edited manually.
-   **Portability:** Where practical, allow stable identifiers such as
    UUID/PARTUUID/LABEL in addition to `/dev/...` paths so profiles
    survive device-name changes.
-   **Priority:** Major usability / repeat-install feature
-   **Regression test:** Save a complete configuration, restart the
    installer, load it, verify all non-secret choices are restored,
    verify passwords/passphrases are still requested, and verify a
    deliberately missing storage device is detected before any
    destructive operation.

### 29. Returning from final chroot should go directly back to installer menu

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r3.sh`
-   **Area:** Final chroot / installer navigation
-   **Current behavior:** After exiting the BFS chroot, the installer
    prints:

``` text
Returned from the BFS chroot.

Press Enter to continue...
```

-   **Desired behavior:** Remove the terminal pause entirely. After the
    chroot exits successfully, return directly to the installer menu (or
    the appropriate post-install menu) without requiring an extra Enter
    key.
-   **UI:** If a message is desired, show it briefly in Dialog or simply
    return to the menu; do not drop to raw terminal output.
-   **Priority:** UI/workflow cleanup
-   **Regression test:** Enter the final BFS chroot, exit it, and verify
    the installer immediately returns to the menu with no raw
    `Press Enter to continue...` prompt.

### 30. Encrypted storage is not activated automatically at boot

-   [x] Fix

-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r4.sh`

-   **Area:** GRUB / Dracut kernel command line / encrypted-root boot

-   **Severity:** Critical boot blocker

-   **Observed first-boot behavior:** GRUB passed the Btrfs root
    filesystem UUID (`root=UUID=d342daa4-...`) but no `rd.luks.uuid=`
    parameter. Dracut waited for that Btrfs UUID for roughly 200
    seconds, then dropped to the debug shell because
    `/dev/mapper/luksroot` had never been created.

-   **Root LUKS proof:** `/dev/vda4` correctly reports
    `TYPE=crypto_LUKS` with UUID `d202ab19-7873-49cf-b625-53d4f8471d06`.
    Manually running `cryptsetup open /dev/vda4 luksroot` immediately
    exposed the expected Btrfs UUID
    `d342daa4-1c49-4616-bf94-bc6cd2690055`, after which exiting the
    Dracut shell allowed boot to continue.

-   **Encrypted RAID proof:** The installed system then assembled
    `/dev/md0` RAID5 successfully with all 5/5 members, but
    `/dev/mapper/cryptraid` was absent. `/dev/md0` correctly reported
    `TYPE=crypto_LUKS` with UUID `e46a2023-298f-475e-8627-32847f93411b`.
    Manually running `cryptsetup open /dev/md0 cryptraid` followed by
    `vgchange -ay` exposed the `bfs-vg/home` and `bfs-vg/var` LVs and
    allowed boot to complete.

-   **Current GRUB defaults:** `/etc/default/grub` contains only
    `GRUB_CMDLINE_LINUX_DEFAULT="consoleblank=1800"`.

-   **Dracut detection proof:** `dracut --print-cmdline` detects at
    least the encrypted root and recommends
    `rd.luks.uuid=luks-d202ab19-7873-49cf-b625-53d4f8471d06`.

-   **Desired behavior:** During bootloader/initramfs configuration,
    derive required Dracut arguments from the actual selected storage
    topology and add them to the GRUB kernel command line. At minimum
    include every LUKS container needed for the installed filesystem
    tree. For this topology that means the root LUKS UUID and the
    LUKS-on-MD UUID; also ensure the MD/LVM portions required to reach
    encrypted RAID-backed filesystems are not disabled in early boot.

-   **Suggested arguments for this test topology:**
    `rd.luks.uuid=luks-d202ab19-7873-49cf-b625-53d4f8471d06`,
    `rd.luks.uuid=luks-e46a2023-298f-475e-8627-32847f93411b`, plus the
    LVM/MD activation arguments recommended by root-run
    `dracut --print-cmdline` for the active layout.

-   **Installer validation:** Before declaring installation complete,
    compare the generated GRUB command line with
    `dracut --print-cmdline`/the detected storage topology and fail or
    warn if an encrypted root lacks an `rd.luks.uuid=` argument.

-   **Regression test:** Rebuild initramfs and GRUB, cold boot with no
    mappings pre-opened, verify the boot process prompts for required
    LUKS passphrase(s), creates `luksroot` and `cryptraid`
    automatically, assembles `/dev/md0`, activates `bfs-vg`, mounts `/`,
    `/home`, and `/var`, and reaches the normal login without a
    Dracut/emergency-shell intervention.

-   **Confirmed root cause / proof:** Explicit `rd.luks.uuid=` arguments
    fixed automatic encrypted-root activation. `rd.md=1` alone was not
    sufficient to assemble the MD array in early boot. Adding `rd.auto`
    caused `/dev/md0` to assemble automatically with all 5/5 members,
    after which Dracut found the LUKS container on `/dev/md0`, prompted
    for it, activated LVM, and booted normally.

-   **Permanent implementation:** r4 derives storage arguments
    dynamically from `/etc/crypttab`, `/etc/fstab`, live LVM metadata,
    and the detected RAID requirement. It writes storage arguments to
    `GRUB_CMDLINE_LINUX` in `/etc/default/grub` so they persist across
    future kernel upgrades and also apply to recovery entries.
    `consoleblank=1800` remains in `GRUB_CMDLINE_LINUX_DEFAULT`.

-   **Generated arguments:** MD RAID adds `rd.auto rd.md=1`; every
    required crypttab UUID adds `rd.luks.uuid=luks-<UUID>`; every
    selected filesystem backed by an LV adds `rd.lvm.lv=<VG>/<LV>`.

-   **Validation:** After `grub-mkconfig`, r4 verifies that the
    generated Linux entries contain all required RAID/LUKS/LVM arguments
    and also checks recovery entries when present.

### 31. "Assemble existing arrays" aborts clean install when no arrays exist

-   [x] Fix
-   **Implemented in:**
    `install-bfs-menu-v50-tracker-fixed-r6-classic-slackware.sh`
-   **Area:** Software RAID / assemble-existing workflow / error
    handling
-   **Observed behavior:** On a deliberately clean target with all
    previous MD signatures wiped, selecting "Assemble existing arrays"
    runs `mdadm --assemble --scan`. `mdadm` correctly returns non-zero
    with `No arrays found in config file or automatically`, but the
    installer's global ERR trap treats that expected result as fatal and
    aborts near line 1777.
-   **Root cause:** The r5 function attempted to tolerate the command
    with `set +e`, but a bare failing command can still interact with
    the installer's ERR trap. The command must execute in a conditional
    context where failure is explicitly handled.
-   **Desired behavior:** No existing arrays is a normal condition on a
    fresh install. Show a Dialog message explaining that no arrays were
    found and return to the RAID menu so the user can choose
    `Create a new array`.
-   **Fix:** Run `mdadm --assemble --scan` inside an `if` condition,
    capture its status without triggering the fatal ERR path, and
    distinguish "no arrays exist" from a partial/real assembly failure.
-   **Regression test:** Wipe all MD member signatures, enter Software
    RAID -\> Assemble existing arrays, verify the installer shows a
    non-fatal "No existing RAID arrays were found" Dialog and returns to
    the RAID menu.

### 32. LUKS mapper name is lost after prompt

-   [x] Fix
-   **Implemented in:**
    `install-bfs-menu-v50-tracker-fixed-r7-classic-slackware.sh`
-   **Area:** LUKS create/open workflow / Bash variable scoping
-   **Observed behavior:** LUKS2 formatting succeeds, but the installer
    reports
    `The new container was created, but /dev/mapper/ could not be opened.`
    The mapper name is blank, `/dev/md0` contains a valid LUKS2 header,
    and `/dev/mapper/cryptraid` remains inactive.
-   **Root cause:** `ask_mapping_name()` declared a local variable named
    `mapping` while also receiving `mapping` as the caller's
    output-variable name. Because Bash local variables are dynamically
    scoped, `printf -v "$result_variable"` updated the helper's local
    `mapping`, leaving `luks_menu`'s `mapping` empty.
-   **Fix:** Rename the helper-local value to `selected_mapping`, so
    `printf -v "$result_variable"` writes back to the caller's `mapping`
    variable.
-   **Regression test:** Create a LUKS container on `/dev/md0`, accept
    the default mapper name `cryptraid`, verify `/dev/mapper/cryptraid`
    is created and active, then continue into LVM setup.

### 33. Active MD RAID array disappears from LUKS target selector

-   [x] Fix
-   **Implemented in:**
    `install-bfs-menu-v50-tracker-fixed-r8-classic-slackware.sh`
-   **Area:** LUKS target discovery / MD RAID integration
-   **Observed behavior:** After creating `/dev/md0`, the RAID array was
    no longer offered as a target when creating a new LUKS container,
    even though `/proc/mdstat` showed the array active.
-   **Root cause:** LUKS target discovery depended primarily on
    `lsblk TYPE` matching `raid*`. MD device TYPE reporting can vary
    with util-linux/array state, so a valid assembled `/dev/md*` device
    could be omitted.
-   **Fix:** Enumerate active MD arrays directly from `/proc/mdstat`
    first, add them explicitly to the LUKS candidate list, deduplicate
    them against the later `lsblk` scan, and continue suppressing the
    individual member partitions.
-   **Regression test:** Create `/dev/md0`, enter LUKS -\> Create a new
    LUKS container, verify `/dev/md0` appears while its member
    partitions do not.

### 34. Existing LUKS selector duplicates an MD-backed LUKS container

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r21.sh`
-   **Area:** LUKS reopen UI / device deduplication
-   **Observed behavior:** A LUKS container on `/dev/md0` appeared once
    for every RAID member because recursive `lsblk` repeated the same MD
    path.
-   **Fix:** Deduplicate LUKS candidates by canonical device path before
    building the Dialog menu.
-   **Regression test:** Close an MD-backed LUKS mapping, choose Open
    existing LUKS, and verify `/dev/md0` appears exactly once.

### 35. LVM PV selector duplicates RAID/LUKS mapper paths

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r21.sh`
-   **Area:** LVM physical-volume UI / device deduplication
-   **Observed behavior:** `/dev/mapper/cryptraid` could appear multiple
    times because recursive `lsblk` repeated descendants beneath each MD
    member.
-   **Fix:** Deduplicate LVM candidate devices by path before presenting
    the checklist.
-   **Regression test:** With RAID -\> LUKS active, verify
    `/dev/mapper/cryptraid` appears exactly once in the PV selector.

### 36. Volume-group creation should select from existing physical volumes

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r21.sh`
-   **Area:** LVM UI / volume-group creation
-   **Current behavior:** Creating a volume group asks for
    physical-volume device path(s) as free-form text.
-   **Desired behavior:** Query actual initialized physical volumes with
    `pvs` and present them in a Dialog checklist. Allow selecting one or
    more PVs with Space, then create the requested VG from those
    selections.
-   **Suggested flow:** `Create PV` -\> device checklist -\> `pvcreate`;
    `Create VG` -\> deduplicated existing-PV checklist -\> `vgcreate`;
    `Create LV` -\> existing-VG selector -\> LV name/size -\>
    `lvcreate`.
-   **Why:** Prevents typing mistakes, prevents selecting devices that
    are not initialized PVs, and makes the LVM workflow consistent with
    the rest of the storage UI.
-   **Related cleanup:** Apply the same device-path deduplication rule
    used for Issues #34/#35 so RAID/LUKS-backed PVs appear only once.
-   **Regression test:** Create a PV on `/dev/mapper/cryptraid`, choose
    Create volume group, verify the PV appears exactly once in the
    checklist, select it, create `bfs-vg`, and confirm `vgs`/`pvs` show
    the expected relationship.

### 37. Filesystem confirmation does not show the selected filesystem plan

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r21.sh`
-   **Area:** Filesystem assignment / confirmation UI
-   **Current behavior:** After selecting devices, filesystem actions,
    and mount points, the final Yes/No confirmation only asks
    `Use these filesystem and mount-point selections?` and does not
    display the actual selections.
-   **Expected behavior:** The confirmation screen itself must show
    every selected device, its mount point, and whether it will be
    formatted or preserved before the user chooses Yes or No.
-   **Required display:** For each selected target show at least
    `Device`, `Mount point`, and an unambiguous action such as
    `FORMAT as btrfs`, `FORMAT as ext2`, `FORMAT as vfat`,
    `FORMAT as swap`, or `KEEP existing filesystem / do not format`.
-   **Implementation note:** The installer already builds
    `storage_selection_summary_text()`, but the current Dialog `--yesno`
    confirmation does not include that summary text. Embed the generated
    filesystem plan directly into the confirmation prompt (or use an
    equivalent confirmation Dialog that presents the full plan before
    Yes/No).
-   **Regression test:** Assign `/`, `/boot`, `/boot/efi`, swap,
    `/home`, `/var`, etc.; select a mix of format and keep actions;
    choose Done; verify the very next confirmation visibly lists every
    device, mount point, and format/keep action before accepting Yes.

### 38. Final review does not show configured LVM volume groups or logical volumes

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r21.sh`
-   **Area:** Final installation review / LVM summary
-   **Observed behavior:** The Review selections screen reports
    `LVM Enabled: yes` but shows `Volume Group: none` and
    `Logical Volumes: none` even after the VG/LVs were created and are
    in use.
-   **Expected behavior:** The final review must enumerate the actual
    active/selected LVM topology instead of only reporting that LVM is
    enabled.
-   **Required display:** Show each VG name and each LV beneath it,
    including at least the LV path/name and size. Where possible, also
    show the backing PV(s) so the user can verify the complete
    `PV -> VG -> LV` chain before installation.
-   **Suggested data source:** Query live LVM metadata with `pvs`,
    `vgs`, and `lvs` rather than relying only on installer state
    variables, because VGs/LVs may have been created or activated
    through multiple paths.
-   **Example:** `Volume Group: bfs-vg`;
    `Logical Volumes: /dev/bfs-vg/home (500G), /dev/bfs-vg/var (500G)`;
    `Physical Volume: /dev/mapper/cryptraid`.
-   **Regression test:** Create the RAID -\> LUKS -\> LVM layout, open
    Review selections, and verify the real VG and all LVs are listed
    instead of `none`.

### 39. Make the Classic Slackware theme more authentically nostalgic and make it the default

-   [x] Enhancement
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r21.sh`
-   **Area:** Dialog theme / visual styling in installer and
    `bootstrap.sh`
-   **Current behavior:** The Classic Slackware theme captures the
    general cyan/blue/yellow palette, but the screen is too uniformly
    cyan and the normal text/border contrast feels flatter and more
    modern than the classic Slackware `setup` appearance. Both scripts
    currently default to another theme unless a saved setting or
    environment override selects Slackware.
-   **Desired behavior:** Tune only the Classic Slackware theme to more
    closely resemble the nostalgic ncurses/Dialog Slackware installer
    look while leaving all other themes available, and make **Classic
    Slackware the default theme for both the installer and
    `bootstrap.sh`** on a fresh configuration.
-   **Default-selection behavior:** Change the built-in fallback/default
    theme in both scripts to `slackware`. Existing users who already
    have a saved theme preference should keep that saved preference;
    explicit environment overrides such as `BFS_INSTALLER_THEME` /
    `BFS_BOOTSTRAP_THEME` should continue to take precedence.
-   **Visual changes to investigate:** Use a black terminal/screen
    background with cyan dialog panels; use black/dark normal dialog
    text; bright yellow dialog titles; strong blue active-selection bars
    with bright white text; vivid red/blue menu tags or accelerator
    characters; yellow selected tags where appropriate; stronger
    gray/white border and scrollbar contrast; and enable the classic
    Dialog drop-shadow/raised-window effect for this theme.
-   **Buttons:** Active buttons should have the high-contrast old Dialog
    appearance (blue background with bright white/yellow text); inactive
    buttons should remain clearly distinguishable against the cyan
    dialog.
-   **Scope:** Apply the same Classic Slackware styling consistently to
    both the BFSOS installer and `bootstrap.sh`. Do not alter the other
    selectable themes.
-   **Regression test:** Cycle through installer and bootstrap menus,
    yes/no prompts, checklists, password/input boxes, scrolling review
    dialogs, and storage menus using Classic Slackware. Verify
    readability, selection visibility, borders/shadows, and a consistent
    nostalgic Slackware `setup` appearance.

### 40. Add explicit support for separate `/usr` and general non-root mount ordering

-   [x] Enhancement
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r21.sh`
-   **Area:** Filesystem layout / mount ordering / Dracut early-boot
    dependencies
-   **Current concern:** The installer supports additional mount points,
    but separate `/usr` needs stronger handling than ordinary mounts
    such as `/opt`, `/srv`, `/var`, or `/home`.
-   **Required behavior for `/usr`:** Treat `/usr` as an
    early-boot-critical filesystem. Ensure the final initramfs can reach
    every storage layer required to mount it (plain block device, LUKS,
    MD RAID, LVM, etc.), generate the correct `/etc/fstab` entry, and
    include `/usr` in the same storage-dependency validation used for
    root.
-   **Dracut module requirement:** When `/usr` is a separate filesystem,
    automatically add Dracut's `usrmount` module to the generated BFS
    storage config (for example `add_dracutmodules+=" usrmount "`). If
    `/usr` depends on LUKS, MD RAID, or LVM, also include the
    corresponding `crypt`, `mdraid`, and/or `lvm` modules based on the
    actual `/usr` ancestry.
-   **Initramfs validation:** After rebuilding the initramfs, verify
    that the image contains `usrmount` whenever `/usr` is separate, plus
    every required supporting storage module. Fail or warn before reboot
    if the early-boot `/usr` dependency cannot be satisfied.
-   **General mount-order rule:** Mount all selected filesystems before
    rootfs extraction and before chroot/package configuration so files
    destined for separate mount points such as `/usr`, `/opt`, `/var`,
    or `/home` are written to the correct filesystem instead of being
    placed underneath the future mount point on `/`.
-   **Normal additional mounts:** `/opt`, `/srv`, `/var`, `/home`,
    `/tmp`, and other non-early-boot mount points can use the normal
    additional-filesystem path, but they still must be mounted before
    extraction/configuration when their content is part of the base
    system or installed packages.
-   **Validation:** Before installation, detect duplicate/nested
    mount-point conflicts and establish parent-before-child mount order.
    Before first boot, verify `/usr` is reachable from the initramfs
    when it is separate.
-   **Regression tests:** Test at least (1) separate plain `/usr`; (2)
    `/usr` on LVM; (3) `/usr` on LUKS/LVM or RAID-backed storage;
    and (4) separate `/opt` to confirm files are extracted onto the
    intended filesystem. For every separate-`/usr` case, inspect the
    final initramfs and confirm `usrmount` and the required storage
    modules are present before cold boot.

### 41. Add installer accessibility option for larger virtual-console font

-   [x] Enhancement
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r21.sh`
-   **Area:** Accessibility / installer settings / Linux virtual console
-   **Motivation:** High-DPI and 4K displays can make the default Linux
    virtual-console font difficult to read. The installer should provide
    an easy large-font mode for users with low vision.
-   **Installer setting:** Add a Settings option such as
    `Console font size` with at least `Default`, `16`, and `20` choices.
    Apply the selected font immediately to the live installer console so
    menus and text become easier to read during installation.
-   **Runtime-only switch:** Add a command-line/environment switch that
    enables large-console mode when launching the installer from a
    terminal without permanently changing the selected installed-system
    console font. Example interfaces could be `--large-console`,
    `--console-font=16`, `--console-font=20`, or an environment variable
    such as `BFS_CONSOLE_FONT=20`.
-   **Installed-system option:** Allow the user to choose whether the
    selected large font should also be written into the installed
    system's vconsole configuration so the same larger font is used at
    boot/login after installation.
-   **Implementation direction:** Use `setfont` with an installed
    console font that is known to exist. Detect available PSF fonts
    before presenting sizes, and gracefully fall back to the current
    font if the requested font is unavailable.
-   **Persistence:** Save the installer UI font preference alongside the
    existing installer settings, while keeping the runtime-only launch
    switch able to override it for the current run.
-   **High-DPI behavior:** Do not assume a fixed screen resolution. The
    feature should be font-size based so it works on 1080p, 1440p, 4K,
    and VM consoles.
-   **Regression tests:** Test the installer on a normal console and a
    4K/high-DPI console; verify switching between Default/16/20 applies
    immediately; verify the launch-time switch works; verify the
    installed-system vconsole font is only changed when explicitly
    requested.

## Previously Identified / Fixed During This Test Cycle

### make-ca CA bundle compatibility

-   [x] Add `/etc/ssl/certs/ca-certificates.crt` compatibility symlink
    to the make-ca port.
-   [x] Correct make-ca description.
-   [x] Confirm make-ca 1.16.1.
-   [x] Remove circular `make-ca -> p11-kit -> make-ca` package
    dependency.
-   [x] `ports -u` works after CA fix.

### LUKS / cryptsetup

-   [x] cryptsetup 2.8.7 port installs successfully.
-   [x] Complete RAID + LUKS + LVM functional boot proof. Fresh r4
    installer regression still recommended.
-   [x] Complete encrypted-root boot proof after adding the confirmed
    GRUB/Dracut arguments from Issue #30.

## New Issues During Testing

*Add each new issue below before continuing so it is not forgotten.*

### Issue

-   [ ] Fix
-   **Area:**
-   **Current behavior:**
-   **Desired behavior:**
-   **Priority:**
-   **Regression test:**

## Final v50 Cleanup Checklist

-   [x] Convert remaining text-mode submenus/prompts to Dialog where
    appropriate.
-   [ ] Verify Back/Cancel works from every storage submenu without
    terminating installer.
-   [ ] Verify RAID member selector only shows appropriate partitions.
-   [ ] Verify already-selected RAID members disappear from subsequent
    selection choices.
-   [ ] Verify RAID arrays are detected correctly even if Linux
    assembles them as `/dev/md127` instead of `/dev/md0`.
-   [x] Verify LUKS detection automatically installs cryptsetup.
-   [x] Verify `/etc/crypttab`.
-   [x] Verify Dracut includes required `crypt`, `mdraid`, and `lvm`
    support.
-   [x] Verify GRUB kernel command line for encrypted root.
-   [x] Verify RAID + LUKS + LVM survives reboot with the confirmed
    Issue #30 arguments.
-   [ ] Verify Snapper configs and initial snapshots.
-   [ ] Verify EFI GRUB installation and fallback
    `EFI/BOOT/BOOTX64.EFI`.

## v50 Tracker Fix Build

-   **Generated:** 2026-08-09
-   **Script:** `install-bfs-menu-v50-tracker-fixed-r3.sh`
-   **Syntax check:** `bash -n` passed.
-   **r2 additions:** Dialog base-archive path input, RAID review
    generated from live mdadm state, filesystem-selection loop now uses
    an explicit Done action, and make-ca release 4 removes the
    ca-certificates file conflict.
-   **Critical crypttab change:** active dm-crypt mappings now obtain
    their backing device from `cryptsetup status` rather than
    `lsblk PKNAME`, which was blank for the reopened mappings in this
    test.
-   **Test next:** reuse the existing RAID/LUKS/LVM topology, select the
    filesystems/mount points, and run through installation to verify
    crypttab, dracut, GRUB, and encrypted-root boot.

## r3 Remaining-Changes Build

-   **Generated:** 2026-08-09
-   **Script:** `install-bfs-menu-v50-tracker-fixed-r3.sh`
-   **Syntax check:** `bash -n` passed.
-   **Implemented:** intelligent mount-point defaults; filesystem plan
    embedded directly in the final Yes/No confirmation; Current Storage
    Devices moved to Dialog; git + wget default on; final chroot returns
    directly to the installer menu.
-   **Profiles:** added Save, Save As, and Load under Installer
    Settings. Profiles exclude passwords/passphrases and validate saved
    block-device paths. Full RAID/LUKS/LVM recreation remains
    intentionally tracked as partial until those menus are converted
    from immediate destructive actions to a declarative storage plan.

## r4 Boot-Storage Fix Build

-   **Generated:** 2026-08-09
-   **Script:** `install-bfs-menu-v50-tracker-fixed-r4.sh`
-   **Issue #30:** dynamically generates permanent GRUB/Dracut storage
    arguments and stores them in `/etc/default/grub`; RAID adds the
    confirmed `rd.auto rd.md=1`, LUKS UUIDs come from `/etc/crypttab`,
    and required LV arguments are derived from `/etc/fstab` plus LVM
    metadata.
-   **Future kernels / recovery:** storage arguments are written to
    `GRUB_CMDLINE_LINUX`, not only the generated `grub.cfg`, so later
    `grub-mkconfig` runs and recovery entries retain the required
    storage topology.
-   **Validation:** installer verifies generated normal/recovery GRUB
    entries contain required RAID/LUKS/LVM arguments.
-   **Issue #21:** fixed the live `/proc/mdstat` parser that could
    report `RAID enabled: YES` while listing arrays as `none`.
-   **Additional UI cleanup:** assembling existing RAID arrays and
    viewing RAID details now stay in Dialog instead of dropping to raw
    terminal output with `Press Enter to continue...`.
-   **Still partial by design:** Issue #28 profile support does not
    recreate RAID/LUKS/LVM destructively from a profile until storage
    setup is refactored into a declarative plan.

## r21 Storage / UI / Accessibility Polish Build

-   **Generated:** 2026-08-10
-   **Installer:** `install-bfs-menu-v50-tracker-fixed-r21.sh`
-   **Bootstrap:** `bootstrap-r21-classic-slackware-default.sh`
-   **Syntax checks:** `bash -n` passed for both scripts.
-   **Issues #34/#35:** deduplicate MD-backed LUKS and LVM device paths.
-   **Issue #36:** VG creation now selects from real unassigned PVs; LV
    creation selects from real VGs.
-   **Issue #37:** filesystem confirmation now embeds the full
    device/mount/FORMAT-or-KEEP plan before Yes/No.
-   **Issue #38:** final review queries live `pvs`, `vgs`, and `lvs`
    metadata.
-   **Issue #39:** Classic Slackware is the fresh-install default in
    installer and bootstrap, with black screen, cyan panels, stronger
    borders, blue selections, and Dialog shadow.
-   **Issue #40:** non-root filesystems are mounted parent-before-child
    before extraction; separate `/usr` causes `usrmount` to be forced
    into the generated Dracut config and verified in the completed
    initramfs.
-   **Issue #41:** installer Settings now provide Default/16/20
    console-font choices, optional installed-system persistence, plus
    runtime-only `--large-console`, `--console-font SIZE`, and
    `BFS_CONSOLE_FONT` overrides.
-   **Issue #28 remains intentionally partial:** profile replay does not
    yet recreate destructive RAID/LUKS/LVM topology; that still requires
    a declarative storage planner and must never store passphrases.

## r22 Follow-up Issues Found During VM Regression Testing

### 42. Add a destructive storage-reset helper for repeated installs and recovery

-   [x] Fix / enhancement revalidated
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r27.sh`
-   **r27 regression fix:** Expanded MD detection to report active
    arrays and inactive member metadata with `mdadm --examine`; the
    destructive checklist now retains RAID-member devices after array
    deactivation and labels them explicitly before zeroing
    superblocks/wiping selected metadata.
-   **Area:** Installer Settings / storage maintenance / test workflow
-   **Goal:** Add an explicit Settings action that detects old LVM,
    LUKS, and MD RAID state and can tear it down cleanly before a fresh
    installation.
-   **UI:** Add a clearly destructive option such as
    `Reset existing storage metadata...`. Never run it automatically.
-   **Detection:** Before confirmation, enumerate active and inactive MD
    arrays, LUKS mappings/containers, LVM PVs/VGs/LVs, swap devices,
    mounted target filesystems, and stale filesystem/signature metadata.
-   **Preview:** Show exactly what will be affected before doing
    anything: mounts to unmount, swap to disable, VGs/LVs to
    deactivate/remove, LUKS mappings to close, MD arrays to stop, member
    devices whose MD superblocks will be removed, and devices on which
    `wipefs` will run.
-   **Safety:** Require an explicit destructive confirmation. Exclude
    the live installer media, BFSOS source/build disk, and any device
    not selected/confirmed by the user. Never guess that an unrelated
    disk is safe to erase.
-   **Order of operations:** Unmount target filesystems -\> swapoff -\>
    deactivate/remove LVs/VGs/PVs as requested -\> close LUKS mappings
    -\> stop MD arrays -\> zero MD superblocks when requested -\> run
    `wipefs` on confirmed backing devices/arrays -\> `udevadm settle`.
-   **Modes:** Ideally provide both `Deactivate only` and
    `Destroy metadata / fresh start` so normal recovery work does not
    require wiping anything.
-   **Why:** Repeated VM installer testing currently requires many
    manual `vgchange`, `cryptsetup close`,
    `mdadm --stop/--zero-superblock`, and `wipefs` commands.
-   **Regression test:** Build RAID -\> LUKS -\> LVM storage, leave it
    active, invoke the reset helper, confirm the preview is correct,
    perform a full reset, and verify `pvs`, `vgs`, `lvs`, `/dev/mapper`,
    `/proc/mdstat`, and `lsblk -f` show the expected clean state while
    the BFSOS build disk remains untouched.

### 43. Partition/filesystem Cancel must return to Storage setup, not abort installation

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
-   **Area:** Storage assignment / Dialog navigation / error handling
-   **Observed behavior:** Cancelling the partition/filesystem selection
    path can escape as a non-zero return and trigger
    `ERROR: Installation cancelled`, invoking fatal cleanup.
-   **Desired behavior:** `Back` or Dialog Cancel returns to Storage
    setup. Only an explicit `Cancel installation`/Quit action may
    terminate the installer.
-   **State preservation:** RAID/LUKS/LVM objects already created should
    remain available when returning to Storage setup unless the user
    explicitly removes them.
-   **Regression test:** Create RAID/LUKS/LVM state, enter filesystem
    assignment, press Cancel, and verify the installer returns to
    Storage setup with storage state intact and no fatal cleanup.

### 44. Improve failure logging for navigation and generated/chroot failures

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
-   **Area:** Logging / ERR trap
-   **Current behavior:** Some failures produce only
    `ERROR: Installation cancelled` or
    `Installation stopped near line 1`, hiding the command/function that
    actually returned non-zero.
-   **Desired behavior:** Log the failing command, source file, function
    stack, real line number, and exit status. Normal Dialog Back/Cancel
    return codes must be handled explicitly and never reach the fatal
    ERR path.
-   **Log preservation:** Keep the live-environment installer log even
    when target mounts are cleaned up, and copy it into the installed
    system whenever the target remains available.

### 45. Rework filesystem-plan confirmation into a readable scrollable view

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
-   **Area:** Filesystem confirmation UI
-   **Observed behavior:** With many devices/LVs the confirmation table
    wraps across lines and becomes difficult to read.
-   **Desired behavior:** Use a wide, vertically scrollable fixed-column
    view showing at least Number, Device, Action (`FORMAT as ...` /
    `KEEP`), and Mount point. Keep Continue/Back controls clear and
    prevent rows from wrapping into each other.
-   **Priority:** Safety-critical readability before destructive
    formatting.

### 46. Improve mount-point defaults from logical-volume/device names

-   [x] Enhancement
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
-   **Area:** Filesystem assignment / mount-point suggestion
-   **Desired behavior:** Infer common mount points from the final
    LV/device component: `root` -\> `/`, `usr` -\> `/usr`, `opt` -\>
    `/opt`, `home` -\> `/home`, `var` -\> `/var`, `tmp` -\> `/tmp`,
    `srv` -\> `/srv`, and `swap` -\> swap. Keep the suggestion editable.

### 47. Loaded profiles must refresh main-menu configured/pending indicators

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
-   **Area:** Installer profiles / main menu state
-   **Observed behavior:** Profile values appear to load, but sections
    still show `[PENDING]`.
-   **Desired behavior:** After loading a profile, recalculate each
    section status from restored values. Storage may remain pending when
    destructive topology still requires manual recreation.

### 48. Match the Classic Slackware theme to Slackware's actual current dialogrc

-   [x] Enhancement
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh` and
    `bootstrap-r26.sh`
-   **Area:** Installer and bootstrap theme
-   **Reference verified:** Slackware64-current
    `dialog-1.3_20260721-x86_64-1.txz`, `etc/dialogrc.new`
    (`$Id: slackware.rc,v 1.13 2025/12/22 ...`), which Slackware's
    `build_installer.sh` copies into the installer as `/etc/dialogrc`.
-   **Correction to earlier assumption:** Slackware intentionally uses a
    BLUE full-screen background. Do not replace it with black merely to
    look more nostalgic.
-   **Goal:** Make BFSOS `Classic Slackware` match the real Slackware
    dialog palette and behavior as closely as practical, while retaining
    BFSOS-specific text/layout.
-   **Behavior values:** `aspect = 0`, `separate_widget = ""`,
    `tab_len = 0`, `visit_items = OFF`, `use_scrollbar = OFF`,
    `use_shadow = ON`, `use_colors = ON`.
-   **Core palette:** `screen_color = (WHITE,BLUE,OFF)`,
    `shadow_color = (WHITE,BLACK,OFF)`,
    `dialog_color = (BLACK,CYAN,OFF)`, `title_color = (YELLOW,CYAN,ON)`,
    `border_color = (CYAN,CYAN,ON)`.
-   **Buttons:** active `(WHITE,BLUE,ON)`; inactive uses `dialog_color`;
    inactive accelerator/key `(RED,CYAN,OFF)`; inactive label
    `(BLACK,CYAN,ON)`.
-   **Input/search:** input `(BLUE,WHITE,OFF)` with normal border;
    search `(YELLOW,WHITE,ON)`; search title `(WHITE,WHITE,ON)`; search
    border `(RED,WHITE,OFF)`.
-   **Menus/items:** menubox and item use `dialog_color`; selected item
    uses `screen_color`.
-   **Tags:** normal tag uses `title_color`; selected tag uses
    `screen_color`; tag key uses inactive button-key color; selected tag
    key `(RED,BLUE,ON)`.
-   **Checklist/arrows:** check uses `dialog_color`; selected check
    `(WHITE,CYAN,ON)`; up/down arrows `(GREEN,CYAN,ON)`.
-   **Other verified values:** position indicator uses inactive
    button-key color; item-help uses shadow color; active form text uses
    inputbox color; form text `(CYAN,BLUE,ON)`; readonly form item
    `(CYAN,WHITE,ON)`; gauge `(BLUE,WHITE,ON)`;
    border2/inputbox_border2/searchbox_border2/menubox_border2 use
    `dialog_color`.
-   **Scope:** Apply the same authentic Classic Slackware theme
    implementation to both the BFSOS installer and `bootstrap.sh`.
-   **Regression test:** Compare installer/bootstrap menus, input boxes,
    checklists, selected rows, buttons, titles, arrows, shadows, and
    gauges against Slackware's current `dialogrc` behavior.

### 49. Simplify large-console-font persistence

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
-   **Area:** Accessibility / console font settings
-   **Desired behavior:** Selecting `Large 16` or `Large 20` should
    apply immediately to the installer and automatically configure the
    installed BFSOS virtual console to use the same font. Remove the
    separate `Use selected console font after install` question.
    `Default` retains the normal installed-system default.

### 50. Optional Software and sudo should not start as pending

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
-   **Area:** Main-menu status/defaults
-   **Optional Software:** Never show `[PENDING]`; no optional packages
    is valid. Use `[OPTIONAL]` initially and `[CONFIGURED]` after
    choices are made.
-   **Sudo:** If untouched, default to normal sudo authentication
    requiring the user's password and show `[DEFAULT]` (or equivalent),
    not `[PENDING]`.
-   **General rule:** Reserve `[PENDING]` for sections that genuinely
    require user attention before installation can proceed.
-   **Optional package addition:** Add the existing BFSOS
    `wpa_supplicant` port (`ports/core/wpa_supplicant`) to Optional
    Software.

### 51. Review/install forward action should be Continue

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
-   **Area:** Review/install navigation
-   **Desired behavior:** The forward action from Review into
    installation must be labeled `Continue`. `Back` must only return to
    the previous configuration screen. Make cancellation an explicit
    separate action.

### 52. Detect stale signatures on newly created MD arrays

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
-   **Area:** MD RAID -\> LUKS workflow
-   **Observed behavior:** A newly created `/dev/mdX` can expose a stale
    `crypto_LUKS` or filesystem signature from previous contents,
    causing the LUKS `Create new container` selector to hide the
    otherwise valid RAID array.
-   **Desired behavior:** Immediately after MD creation, inspect the
    array with `wipefs`. If stale signatures are present, show them and
    offer an explicit `Wipe signatures`, `Keep`, or `Cancel` choice
    before continuing.
-   **Safety:** Never silently wipe signatures.

### 53. Pre-reboot validation: complex encrypted RAID/LVM/Btrfs install is boot-test ready

-   [x] Validation passed
-   **Area:** Final installation validation / Dracut / GRUB / storage
-   **Validated topology:** UEFI + separate ext2 `/boot`; LUKS
    `cryptroot` -\> LVM `bfs-root` -\> separate Btrfs `/`, `/usr`, and
    `/opt`; MD RAID -\> LUKS `cryptraid` -\> LVM `bfs-vg` -\> separate
    Btrfs `/home` and `/var`; Btrfs snapshot subvolumes; disk swap.
-   **Dracut modules verified in generated initramfs:** `btrfs`,
    `crypt`, `crypt-lib`, `dm`, `lvm`, `mdraid`, `rootfs-block`, and
    `usrmount`.
-   **Separate `/usr` support verified:** initramfs contains Dracut
    `pre-pivot/50-mount-usr.sh`; generated
    `/etc/dracut.conf.d/20-bfs-storage.conf` records
    `Separate /usr: yes` and forces `usrmount crypt lvm mdraid`.
-   **GRUB verified:** generated kernel command line contains
    `root=/dev/mapper/bfs--root-root`, `rootflags=subvol=@`, `rd.auto`,
    `rd.md=1`, both LUKS UUID arguments, and `rd.lvm.lv=bfs-root/root`;
    correct BFSOS kernel and initramfs paths are present.
-   **ZRAM verified:** kernel config has `CONFIG_ZRAM=m` and the
    installed `zram.ko` exists under
    `/lib/modules/7.1.5-BFS-Linux/kernel/drivers/block/zram/`.
-   **Decision:** Do not make further Dracut/GRUB changes before the
    reboot test. The current configuration should be tested as generated
    by the installer.
-   **Next test:** Cleanly leave chroot/unmount, reboot from the
    installed disk, confirm both LUKS prompts/unlocks, MD assembly, both
    VGs, separate `/usr`, `/opt`, `/var`, `/home`, and successful
    systemd userspace boot.

### 54. Update installed release branding URLs from BFS-Linux to BFSOS

-   [x] Fix

-   **Completed:** Installed test system produced BFSOS Codeberg URLs
    correctly, and the installer keeps the extracted os-release
    safeguard. The source `aaa_filesystem` Pkgfile had already been
    corrected in the project tree before this pass.

-   **Area:** `aaa_filesystem` / `/etc/os-release` branding

-   **Observed behavior:** Installed `/etc/os-release` still uses
    `https://codeberg.org/bmadonnaster/BFS-Linux` for `HOME_URL`,
    `SUPPORT_URL`, and `BUG_REPORT_URL` even though the repository has
    been renamed to BFSOS.

-   **Desired behavior:** Change all three generated URLs to the current
    BFSOS repository and BFSOS issues page.

-   **Scope:** Search release/branding files and installer-generated
    metadata for any remaining stale `BFS-Linux` repository references
    so new installs do not recreate them.

-   **Priority:** Cosmetic/non-boot-blocking; fix after the current
    reboot test rather than modifying this installed test system before
    first boot.

-   **r35 safeguard:** The installer now rewrites stale BFS-Linux
    Codeberg URLs in the extracted
    `/etc/os-release`/`/usr/lib/os-release` to BFSOS. The source
    `ports/core/aaa_filesystem/Pkgfile` still needs to be updated
    directly when that port file is supplied; it was not among the
    uploaded files for this pass. \### 55. Rename the blue theme to
    Classic Debian and reproduce Debian's real installer palette from
    source

-   [x] Enhancement

-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh` and
    `bootstrap-r26.sh`

-   **Area:** Installer and bootstrap themes / Debian-inspired theme

-   **Rename:** Change the existing blue-theme display name to **Classic
    Debian** everywhere it appears in installer menus, bootstrap menus,
    saved theme/profile labels, help text, and documentation. Preserve
    the existing internal key where practical for compatibility, or add
    a migration/alias so saved configurations using the old theme name
    still load correctly.

-   **Research source of truth:** Do not rely on screenshots or memory.
    Base the Classic Debian palette on Debian's actual installer
    frontend source.

-   **Primary Debian source:** Debian's installer uses `cdebconf` with a
    `newt` frontend. The authoritative source tree is the Debian
    Installer Team `cdebconf` repository and the versioned Debian
    Sources copies.

-   **Historical evidence:** Debian's `cdebconf` changelog records
    explicit newt color changes, including support for a dark background
    via `FRONTEND_BACKGROUND=dark` and later readability changes for
    select, multiselect, and button colors.

-   **Related palette source:** `newt` itself defines color-set roles
    such as root, border, window, shadow, title, button, active button,
    checkbox, entry, listbox, textbox, helpline, and progress-scale
    colors. Debian's frontend may override or remap these, so inspect
    `cdebconf`'s newt frontend first and use `newt` defaults only where
    Debian leaves them unchanged.

-   **Research targets:** Locate and compare the current and
    historically representative Debian installer newt frontend
    code/config for root/screen, window/dialog, borders/shadows, titles,
    active/inactive buttons, entries, normal/selected menu rows,
    checkboxes/radiolists, help/status text, progress bars, and any
    `FRONTEND_BACKGROUND` logic.

-   **Implementation goal:** Translate the verified Debian installer
    palette into the BFSOS Dialog-based theme as faithfully as practical
    while keeping BFSOS-specific layouts and controls.

-   **Scope:** Apply the renamed **Classic Debian** theme consistently
    to both the BFSOS installer and `bootstrap.sh`; do not alter Classic
    Slackware or other themes.

-   **Compatibility:** Existing saved profiles/configs referring to the
    old blue-theme identifier/name must continue to work and should map
    automatically to Classic Debian.

-   **Regression test:** Compare BFSOS Classic Debian menus, prompts,
    input boxes, checklists, selected rows, buttons, titles, shadows,
    help text, and progress displays against the Debian installer
    source-defined appearance; verify theme selection and saved-profile
    migration work in both installer and bootstrap.

-   **Research starting points:** Debian Installer Team `cdebconf`
    source on Salsa; Debian Sources package history for `cdebconf`;
    `cdebconf` newt frontend source and changelog entries for
    `FRONTEND_BACKGROUND=dark`; Debian `newt` source for base color-set
    definitions where needed.

-   **Source research completed for r26:** Debian `cdebconf` 0.280
    `src/modules/frontend/newt/newt.c` uses `newtDefaultColorPalette`
    unless `FRONTEND_BACKGROUND=dark`; its alternate dark palette
    remains explicitly defined in the frontend. Debian's `cdebconf`
    changelog documents the black-background mode and later
    select/multiselect/button readability changes.

-   **Classic palette basis used in BFSOS:** the normal newt palette
    roles map to white-on-blue root/screen, black-on-light-gray
    window/border, red-on-light-gray title/active button, yellow-on-blue
    entry/selected-list accents, and a white-on-black shadow. Dialog's
    `WHITE` is used as the closest standard-color approximation to newt
    `lightgray`.

-   **Compatibility:** the internal theme key remains `classic`, so
    existing settings/profiles continue loading while the visible name
    changes from `Classic Blue` to `Classic Debian`. \### 56. Add
    explicit early-boot GRUB/LVM arguments for separate `/usr`

-   [x] Fix

-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r26.sh`

-   **Area:** GRUB generation / Dracut early-LVM activation / separate
    `/usr`

-   **Observed boot failure:** With `/usr` on `bfs-root/usr`, Dracut
    loaded `usrmount` and all required storage modules, unlocked
    `cryptroot`, activated `bfs-root/root`, and mounted root, but `/usr`
    failed because `bfs-root/usr` was not activated early. The generated
    kernel command line contained `rd.lvm.lv=bfs-root/root` but omitted
    `rd.lvm.lv=bfs-root/usr`.

-   **Manual proof:** Adding `rd.lvm.lv=bfs-root/usr` to the GRUB kernel
    command line allowed the system to boot successfully.

-   **Required fix:** Whenever `/usr` is on an LVM LV, add an explicit
    `rd.lvm.lv=<VG>/<LV>` argument for that `/usr` LV in addition to the
    root LV argument.

-   **General rule:** Generate explicit `rd.lvm.lv=` arguments for every
    filesystem that is genuinely required in initramfs/early userspace,
    not merely every LV in the system.

-   **Do not over-broaden by default:** Normal late mounts such as
    `/opt`, `/var`, `/home`, `/srv`, and similar filesystems do not need
    explicit early-LVM kernel arguments solely because they are LVs. Let
    normal systemd/fstab activation handle them after switch-root unless
    their ancestry is needed to reach `/usr` or another
    early-boot-critical path.

-   **RAID/LUKS handling:** Continue generating explicit early-boot
    RAID/LUKS arguments from the ancestry of root and separate `/usr`.
    It is safe to include required parent MD/LUKS devices, but avoid
    blindly adding every unrelated RAID/LUKS device in the machine
    because that can trigger unnecessary unlock prompts, array assembly,
    delays, or failures for storage that is not required to boot.

-   **Topology-driven implementation:** Walk the block-device ancestry
    for `/` and `/usr`; collect only the required LVM LVs, LUKS UUIDs,
    and MD arrays; deduplicate arguments; persist them in
    `GRUB_CMDLINE_LINUX`; regenerate `grub.cfg`; and verify the
    generated normal and recovery entries contain all required
    early-storage arguments.

-   **Regression tests:**

    1.  Root on LVM with no separate `/usr`.
    2.  Root + separate `/usr` on different LVs in the same VG.
    3.  `/usr` on LUKS -\> LVM.
    4.  `/usr` on MD RAID -\> LUKS -\> LVM.
    5.  Extra unrelated LVs/RAID/LUKS present for `/home`, `/var`, or
        data; confirm they do not cause unnecessary early boot prompts
        or kernel arguments.

-   **Boot regression confirmed/fixed:** the first cold boot failed
    because only `bfs-root/root` was activated. Manually adding
    `rd.lvm.lv=bfs-root/usr` in GRUB allowed BFSOS to boot successfully.
    r26 now derives explicit `rd.lvm.lv=` arguments from `/` and `/usr`
    only, rather than all LVs.

-   **Topology scope:** required LUKS UUIDs and MD discovery flags are
    likewise derived from the ancestry of `/` and `/usr`, avoiding
    unnecessary unlock prompts or assembly of unrelated data/home
    storage.

## r26 Tracker Implementation Pass

-   **Generated:** 2026-08-10
-   **Installer:** `install-bfs-menu-v50-tracker-fixed-r26.sh`
-   **Bootstrap:** `bootstrap-r26.sh`
-   **Syntax checks:** `bash -n` passed for both scripts.
-   **Issues completed in this pass:** #42, #43, #44, #45, #46, #47,
    #48, #49, #50, #51, #52, #55, #56.
-   **Issue #54 remains open:** `/etc/os-release` URL correction belongs
    in the `aaa_filesystem` port/Pkgfile rather than either of the two
    scripts supplied for this pass.
-   **Storage maintenance:** Settings now includes a previewed
    `Deactivate only` mode and an explicit checklist-driven destructive
    metadata reset. Protected live-root/project storage is excluded.
-   **Filesystem navigation/UI:** Back from filesystem assignment
    returns to Storage setup; the final plan is shown in a wide
    scrollable textbox followed by Continue/Back confirmation; LV names
    such as `usr`, `opt`, `var`, `home`, `tmp`, and `srv` get sensible
    mount-point suggestions.
-   **Profiles/status:** loaded profiles recalculate configured/pending
    state; Optional Software defaults to `OPTIONAL`; sudo defaults to
    password-authenticated `DEFAULT`.
-   **Optional software:** `wpa_supplicant` is available as an optional
    package.
-   **Console accessibility:** selecting Large 16/20 automatically
    persists that choice to the installed system; selecting Default
    disables persistence.
-   **Themes:** Classic Slackware now uses the exact Slackware
    `dialogrc` values gathered during testing; Classic Blue is renamed
    Classic Debian and translated from Debian cdebconf/newt source while
    preserving the `classic` internal key.
-   **RAID stale signatures:** newly-created arrays are checked with
    `wipefs -n` and the user is explicitly offered a safe wipe/keep
    choice.
-   **Failure diagnostics:** ERR trap now records exit status, source,
    line, function, command, and caller instead of `line 1`.
-   **Install navigation:** final installation confirmation is
    Continue/Back; Back returns to configuration instead of triggering
    fatal cleanup.
-   **Early boot storage:** GRUB arguments are derived from
    boot-critical `/` and `/usr` ancestry. Separate `/usr` on LVM now
    receives its own `rd.lvm.lv=` parameter.

## r27 Follow-up Issues Found During Installed-System Testing

### 57. Fix GRUB/Dracut topology logic for complex storage

-   [x] Fix --- reopened after r27 regression test
-   **Implemented in r35:**
    `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or
    `bootstrap.sh` as applicable.
-   **Area:** GRUB generation / Dracut / complex storage
-   **Observed behavior:** The completed install did not automatically
    emit the complete/correct boot-storage arguments required by the
    tested topology. Manual correction was required before reboot.
-   **Required behavior:** Derive boot-critical storage ancestry and
    emit the required `rd.luks.uuid=`, `rd.md.uuid=`, and `rd.lvm.lv=`
    arguments. Finalize `/etc/crypttab` and mdadm configuration before
    rebuilding the initramfs, then regenerate `grub.cfg` and validate
    the generated boot entries/initramfs.
-   **Regression scope:** LUKS -\> LVM and MD RAID -\> LUKS -\> LVM,
    including separate `/usr`, `/opt`, `/home`, `/var`, and complex
    Btrfs layouts.
-   **r27 regression #1 --- truncated MD UUID:** The MD UUID parser
    emitted only the first colon-delimited field (`rd.md.uuid=4a9b5206`)
    instead of the complete mdadm UUID
    (`rd.md.uuid=4a9b5206:8ebe46e5:6d41cbba:3468e1e1`). Preserve the
    complete value exactly as reported by `mdadm --detail` /
    `mdadm --detail --scan`; do not parse it with a generic colon field
    split.
-   **r27 regression #2 --- stale verifier:** The generator switched to
    explicit `rd.md.uuid=...`, but the GRUB verifier still failed the
    install with `boot-critical RAID storage requires rd.auto`.
    Generator and verifier must use the same storage model. A valid
    explicit `rd.md.uuid=` must satisfy RAID verification; `rd.auto`
    must not be required when explicit MD UUIDs are emitted.
-   **r27 regression #3 --- missing explicit LUKS cmdline:** The tested
    RAID -\> LUKS -\> LVM plus separate LUKS root topology generated no
    `rd.luks.uuid=` values even though `/etc/crypttab` contained both
    mappings. Generate explicit LUKS UUID arguments for every
    boot-required encrypted layer in the selected storage ancestry.
-   **Known-good manual result for this test topology:**
    -   `rd.luks.uuid=77d5c3fb-083b-4ea3-9aa8-11f4e85d334e`
    -   `rd.luks.uuid=a82d9766-a424-4530-b4a7-9b8de91d0b2c`
    -   `rd.md.uuid=4a9b5206:8ebe46e5:6d41cbba:3468e1e1`
    -   `rd.lvm.lv=bfs-root/root`
    -   `rd.lvm.lv=bfs-root/usr`
    -   `rd.lvm.lv=bfs-raid/home`
    -   `rd.lvm.lv=bfs-raid/var`
-   **Initramfs validation from failed r27 test:** The initramfs already
    contained `crypttab`, `mdadm.conf`, `cryptsetup`, `mdraid`, and LVM
    support, so this failure was isolated to GRUB/storage-command-line
    generation and verification rather than missing initramfs storage
    tooling.
-   **Post-install menu clarification:** The missing Chroot/Finish menu
    was not a separate post-install-menu bug in this test. The installer
    aborted during final GRUB verification, so it correctly never
    reached the success/post-install menu.
-   **Regression test:** Build the same RAID0 -\> LUKS -\> LVM layout
    plus separate LUKS root, regenerate initramfs/GRUB without manual
    edits, verify full MD UUID preservation, both LUKS UUIDs, all
    required LVs in normal and recovery entries, and confirm the
    installer reaches the final Chroot/Finish menu after validation
    succeeds.

### 58. Correct Review vs Option 10 final-summary navigation labels

-   [x] Fix
-   **Implemented in r35:**
    `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or
    `bootstrap.sh` as applicable.
-   **Area:** Review/install navigation
-   **Observed behavior:** r27 overcorrected the navigation labels so
    both the configuration Review screen and the Option 10 final
    installation summary show `Continue`.
-   **Desired behavior:** The Review/configuration screen must provide
    `Back` so the user can return and change selections. Option 10's
    final installation summary must show `Continue` at the bottom to
    proceed into installation; it must not show `Back`.
-   **Regression test:** Confirm the Review/configuration screen says
    `Back`, then enter Option 10 and confirm the final summary says
    `Continue`. Verify Back actually returns to configuration and
    Continue advances toward installation.

### 59. Consolidate BFSOS logs under `/var/log/bfs`

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r27.sh` and
    `bootstrap-r27.sh`
-   **Area:** Bootstrap/build logging / installer logging
-   **Observed behavior:** Build logs are currently installed under
    `/var/logs/bfs-build/`, while installer logs correctly use
    `/var/log/bfs/installer/`.
-   **Desired layout:** `/var/log/bfs/bfs-build/` for package/bootstrap
    build logs and `/var/log/bfs/installer/` for installer logs.
-   **Cleanup:** Remove new uses of the legacy `/var/logs` path and
    update log-copy/install logic so all BFSOS-specific logs live below
    `/var/log/bfs/`.
-   **r27 implementation:** Bootstrap copies base-package build logs to
    `/var/log/bfs/bfs-build`; installer logs remain
    `/var/log/bfs/installer`.

### 60. Add `wireless_tools` to Optional Software

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r27.sh`
-   **Area:** Optional Software
-   **Package:** `wireless_tools` 30.pre9
-   **Status:** Port built and runtime tools verified during
    installed-system testing.
-   **Desired behavior:** Offer `wireless_tools` in the installer's
    Optional Software selection alongside `wpa_supplicant`.
-   **r27 implementation:** Added `BFS_INSTALL_WIRELESS_TOOLS`, profile
    save/load support, Dialog/text optional-package selection, and
    chroot package-list installation.

## r27 Test Notes

-   Full installer run completed without installer errors before first
    reboot.
-   `wpa_supplicant` 2.11 was verified installed and runnable against
    OpenSSL 4 (`libssl.so.4` / `libcrypto.so.4`).
-   `wireless_tools` was successfully built after correcting the BFSOS
    port to invoke `build_opt` from `pkg_build` and package the
    statically linked utilities without expecting a nonexistent
    `libiw.so.30` from the default upstream build.

### 61. Clear terminal screen on installer/bootstrap exit

-   [x] Fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r27.sh` and
    `bootstrap-r27.sh`
-   **Area:** Installer/bootstrap terminal cleanup / UI
-   **Observed behavior:** Exiting the installer or `bootstrap.sh` can
    leave the full-screen `dialog` background and menu colors painted
    across the terminal instead of restoring a clean shell view.
-   **Desired behavior:** On every normal exit, Cancel/Quit path, and
    handled error exit, restore the terminal state and clear/redraw the
    screen before returning to the shell.
-   **Implementation note:** Centralize terminal cleanup in the existing
    exit/cleanup handler so both the installer and bootstrap
    consistently run the appropriate `clear`/terminal-reset sequence
    after `dialog` is closed. Avoid scattering cleanup calls through
    individual menus.
-   **Regression test:** Exit normally, use Back/Cancel/Quit paths, and
    trigger a handled failure under each theme; confirm the shell
    returns with no stale installer/bootstrap background, colors, cursor
    state, or screen contents.
-   **r27 implementation:** Both scripts centralize terminal reset in
    their EXIT cleanup handlers, reset SGR attributes, show the cursor,
    and clear/redraw `/dev/tty` after restoring `DIALOGRC`.

## r27 Implementation Pass

-   **Generated:** 2026-08-11
-   **Installer:** `install-bfs-menu-v50-tracker-fixed-r27.sh`
-   **Bootstrap:** `bootstrap-r27.sh`
-   **Issues addressed:** #42 regression, #57, #58, #59, #60, #61.
-   **Still open:** #54 (`aaa_filesystem` branding URLs) because the
    port Pkgfile was not part of this script pair.
-   **Required regression test:** run a fresh complex-storage VM install
    and verify generated GRUB/initramfs without manual edits,
    storage-reset RAID detection/destruction, Review button label,
    optional `wireless_tools`, installed log paths, and clean terminal
    exit.

### 62. Change OpenSSH prompt to enable-on-boot wording

-   [x] Fix
-   **Implemented in r35:**
    `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or
    `bootstrap.sh` as applicable.
-   **Area:** Optional software / service configuration
-   **Observed behavior:** The installer currently presents OpenSSH like
    an optional package even though `openssh` is already installed by
    the BFSOS bootstrap/base system.
-   **Desired behavior:** Ask `Do you want to enable OpenSSH on boot?`
    and treat the answer as service configuration for `sshd.service`,
    not as a package-install decision.
-   **Regression test:** Confirm OpenSSH is already present from the
    base system, the installer asks only whether to enable it at boot,
    and the selected answer produces the expected `sshd.service`
    enablement state.

### 63. Run mandatory `prt-get sysup` after `ports -u`

-   [x] Enhancement / fix
-   **Implemented in r35:**
    `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or
    `bootstrap.sh` as applicable.
-   **Area:** Ports synchronization / installed-system upgrade
-   **Reason:** A user may install from an older base rootfs archive.
    Synchronizing the ports tree alone does not upgrade packages already
    present in that base system.
-   **Desired behavior:** After a successful `ports -u`, run
    `prt-get sysup` inside the installed system as a mandatory system
    upgrade before the final initramfs/Dracut and GRUB generation.
-   **Failure behavior:** A failed `prt-get sysup` must stop the
    installation rather than silently continuing with a partially
    upgraded system.
-   **Logging:** Capture the system-upgrade output in the installer log
    so package changes and failures can be diagnosed later.
-   **Regression test:** Test with an intentionally older base archive;
    confirm ports synchronize, installed packages upgrade, failures
    propagate, and final Dracut/GRUB generation occurs only after the
    upgrade succeeds.

## r28 Tracker Update

-   **Generated:** 2026-08-11
-   **Tracker-only update:** No installer/bootstrap code changed in this
    revision.
-   **Reopened:** #58 to distinguish the Review/configuration `Back`
    action from Option 10 final-summary `Continue`.
-   **Added:** #62 OpenSSH enable-on-boot wording/service logic.
-   **Added:** #63 mandatory `prt-get sysup` after `ports -u`, before
    final Dracut/GRUB generation.

### 64. Offer optional package-cache cleanup after successful installation

-   [x] Enhancement
-   **Implemented in r35:**
    `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or
    `bootstrap.sh` as applicable.
-   **Area:** Post-install package/cache cleanup
-   **Timing:** Ask only after all package installation and the
    mandatory `prt-get sysup` have completed successfully, immediately
    before returning to the installer menu.
-   **Prompt:** Ask whether the user wants to clear the built/downloaded
    binary package cache under `/var/cache/pkg/packages/`.
-   **Default:** No. Keeping the cached binary packages can be useful
    for reinstalling packages or troubleshooting without rebuilding
    them.
-   **Yes behavior:** Remove the contents of `/var/cache/pkg/packages/`
    while leaving the directory itself in place.
-   **Scope:** Do not clear `/var/cache/pkg/sources/`; source-cache
    cleanup is outside this option.
-   **Safety:** Do not offer or perform this cleanup during a failed or
    partially completed package upgrade, so cached packages remain
    available for diagnosis/recovery.
-   **Regression test:** Complete an install/update with cached packages
    present, choose No and verify they remain; repeat choosing Yes and
    verify `/var/cache/pkg/packages/` is empty while
    `/var/cache/pkg/sources/` is untouched.

### 65. Tie the bootstrap and installer workflows together

-   [x] Enhancement
-   **Implemented in r35:**
    `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or
    `bootstrap.sh` as applicable.
-   **Area:** Bootstrap menu / installer integration
-   **Goal:** Make the normal BFSOS workflow flow directly from building
    a usable base rootfs into launching the installer, instead of
    treating bootstrap and installation as unrelated entry points.
-   **Installer location:** Move the primary installer script into the
    repository `scripts/` directory. The bootstrap menu should resolve
    it relative to `SCRIPT_DIR` rather than relying on the caller's
    current working directory.
-   **Bootstrap menu:** Add an explicit `Launch BFSOS installer` entry
    that runs the repository installer from `scripts/`.
-   **Installer discovery:** Do not hard-code a single versioned
    installer filename in `bootstrap.sh`. Discover matching installer
    scripts under `scripts/` with a stable pattern (for example
    `install-bfs-menu-v*.sh`), exclude obvious backups/test artifacts
    where practical, and select the newest usable version automatically.
-   **Version selection rule:** Prefer the highest/newest installer
    revision deterministically. If filenames contain a date/time or
    revision component, use that ordering rather than whichever file
    happens to be returned first by the filesystem.
-   **Visibility:** Show the exact installer path/version bootstrap is
    about to launch so the user can see which revision was selected.
-   **Normal workflow:** The common path should make bootstrap stages 1,
    2, and 4 plus rootfs archive creation prominent/required for
    producing an installable BFSOS base.
-   **Stage 3:** Keep the full final-toolchain/base rebuild available,
    but clearly label it **optional**. It is useful for users who
    deliberately want to rebuild the system a second time, but it must
    not be presented as a prerequisite for installation.
-   **Rootfs archive:** Keep creation/compression of the base rootfs
    archive as a mandatory part of the normal build-to-install workflow
    because the installer consumes that archive.
-   **Installer handoff:** Before launching the installer, verify that a
    usable base rootfs archive exists. If not, explain which required
    bootstrap/archive step is incomplete rather than launching into a
    guaranteed failure.
-   **Return behavior:** When the installer exits normally or is
    cancelled, return cleanly to the bootstrap menu with the terminal
    restored.
-   **Direct execution:** Moving the installer under `scripts/` must not
    prevent advanced users from invoking it directly.
-   **Path migration:** Update documentation, helper scripts, tracker
    references, and any hard-coded repository-root installer paths to
    the new `scripts/` location.
-   **Regression test:** From a clean repository, complete the normal
    bootstrap path without stage 3, create the rootfs archive, launch
    the installer from the bootstrap menu, cancel/return, relaunch it,
    and verify paths, permissions, terminal cleanup, archive detection,
    and direct installer execution all work.

### 66. Clarify mandatory vs optional bootstrap stages in the menu

-   [x] UI / workflow enhancement
-   **Implemented in r35:**
    `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or
    `bootstrap.sh` as applicable.
-   **Area:** Bootstrap menu
-   **Goal:** Make it immediately obvious which stages are needed to
    produce an installable BFSOS base and which are optional
    validation/rebuild operations.
-   **Required normal-build stages:** Present bootstrap options 1, 2,
    and 4 as part of the normal required workflow, together with
    mandatory base-rootfs archive creation/compression.
-   **Optional rebuild stage:** Mark option 3 as optional and describe
    it as a second/final rebuild for users who want the additional
    rebuild pass.
-   **Status tracking:** Completion/pending indicators must not treat
    skipped option 3 as an incomplete/error state when the user follows
    the normal installable-base workflow.
-   **Installer readiness:** The new installer-launch entry should base
    readiness on the genuinely required stages and availability of the
    rootfs archive, not on completion of optional stage 3.
-   **Existing archive readiness:** On bootstrap startup, inspect the
    default base-archive directory. If a valid base rootfs archive
    already exists, treat the installable-base requirement as satisfied
    even when the current checkout has no fresh stage markers from this
    session.
-   **Menu status:** Reflect that state clearly in the bootstrap menu
    (for example `READY`/`ARCHIVE AVAILABLE`) so the user can launch the
    installer immediately without rebuilding mandatory stages
    unnecessarily.
-   **Safety:** Archive presence should satisfy installer readiness only
    after validating that the file is readable and matches a supported
    BFSOS base-rootfs archive format.
-   **Regression test:** Verify a user can complete the required
    workflow, intentionally skip stage 3, create the archive, and
    launch/install BFSOS without warnings claiming the build is
    incomplete.

## r29 Tracker Update

-   **Generated:** 2026-08-11

-   **Tracker-only update:** No bootstrap or installer code changed in
    this revision.

-   **Added:** #65 bootstrap-to-installer integration and moving the
    primary installer into `scripts/`.

-   **Added:** #66 distinguish the required bootstrap path from optional
    stage 3 and ensure installer readiness does not depend on stage 3.

-   **Planned workflow:** build required base stages -\> create/compress
    rootfs archive -\> launch installer directly from the bootstrap
    menu.

-   **Status semantics:** Use the three status words consistently:
    `PENDING` means a required prerequisite has not been satisfied;
    `AVAILABLE` means an action can be run now but is not itself a
    completion requirement; `COMPLETE` means the corresponding
    build/verification/archive requirement has been satisfied.

-   **Required stages 1, 2, and 4:** Show `PENDING` until their
    completion checks pass, then `COMPLETE`.

-   **Stage 3 optional rebuild:** Do not show `PENDING` merely because
    it was skipped. Show `AVAILABLE` while it can be run and `COMPLETE`
    after it has actually completed.

-   **Rootfs archive creation:** Show `PENDING` until a valid base
    archive exists, then `COMPLETE`.

-   **Restore actions:** `Restore newest base rootfs archive` and
    `Restore newest temporary toolchain archive` are actions, not
    mandatory stages. Show `AVAILABLE` whenever a valid source archive
    exists. They must not remain `PENDING` just because the user has not
    chosen to restore something.

-   **Chroot:** Show `AVAILABLE` whenever a usable rootfs exists;
    otherwise `PENDING` because there is nothing to enter yet.

-   **Installer launch:** Show `AVAILABLE` whenever a valid base rootfs
    archive exists and the installer can be discovered; otherwise
    `PENDING`. Launching the installer is an action, so it should not be
    labeled `COMPLETE` simply because it was run once.

### 67. Add graphical base-rootfs archive selection and browsing

-   [x] UI / workflow enhancement
-   **Implemented in r35:**
    `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or
    `bootstrap.sh` as applicable.
-   **Area:** Installer base archive selection
-   **Goal:** Avoid requiring the user to manually type a base-rootfs
    archive path when the archive is outside the default location.
-   **Default archive behavior:** First search/check the normal BFSOS
    base-rootfs archive location. If a usable archive exists, show the
    discovered archive and its full path and offer to use it
    immediately.
-   **Newest archive selection:** When multiple valid base archives
    exist in the default location, automatically choose the newest one.
    If the filename contains the BFSOS date/time stamp, sort by that
    embedded timestamp first; fall back to file modification time only
    when a reliable timestamp cannot be parsed from the name.
-   **Deterministic tie-break:** If two candidates resolve to the same
    parsed timestamp, use a stable secondary sort (such as modification
    time then filename) so selection is predictable.
-   **Display:** The detected/default archive screen should identify
    that it is the newest available archive and show the selected
    filename, full path, size, and timestamp before the user accepts it.
-   **Default archive choices:** When an archive is found, provide clear
    actions to use the detected archive, browse/select a different
    archive, or go Back.
-   **Missing-default behavior:** If no usable archive exists in the
    default location, open the file-selection/browse interface
    automatically rather than presenting a dead/default path.
-   **Browse interface:** Use a Dialog file selector such as `--fselect`
    when available so the user can navigate directories and choose the
    base archive interactively.
-   **Archive validation:** After selection, verify the selected path
    exists, is a regular readable file, and uses an archive/compression
    format supported by the installer before accepting it.
-   **Confirmation:** Show the selected archive's full path and useful
    metadata such as file size before committing the selection.
-   **Session behavior:** Preserve the selected archive path for the
    remainder of the installer session and in installer profile/state
    handling where appropriate.
-   **Bootstrap integration:** When the installer is launched from the
    bootstrap workflow added by #65, prefer the rootfs archive just
    created by bootstrap as the detected/default archive.
-   **Text-mode fallback:** If Dialog/file selection is unavailable,
    retain a text-mode path prompt with validation rather than making
    archive selection impossible.
-   **Regression test:** Test with (1) a valid archive in the default
    location, (2) no default archive, (3) choosing a different archive
    despite a valid default, (4) invalid/non-readable selections,
    and (5) launching from bootstrap immediately after archive creation.

## r30 Tracker Update

-   **Generated:** 2026-08-11
-   **Tracker-only update:** No installer/bootstrap code changed in this
    revision.
-   **Added:** #67 interactive base-rootfs archive discovery/browsing
    with default-archive preference, validation, and bootstrap handoff
    support.

## r31 Tracker Update

-   **Generated:** 2026-08-11
-   **Tracker-only update:** No bootstrap or installer code changed in
    this revision.
-   **Updated #65:** Bootstrap installer launch must discover the newest
    versioned installer under `scripts/` instead of hard-coding one
    filename.
-   **Updated #66:** A valid existing base-rootfs archive in the default
    archive directory can satisfy installer readiness and should be
    reflected in bootstrap menu status.
-   **Updated #67:** When multiple default base archives exist, select
    the newest archive deterministically, preferring the date/time
    embedded in the filename when present.

### 69. Normalize bootstrap `PENDING` / `AVAILABLE` / `COMPLETE` status logic

-   [x] UI / workflow fix
-   **Implemented in r35:**
    `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or
    `bootstrap.sh` as applicable.
-   **Area:** Bootstrap menu status indicators
-   **Observed behavior:** The current bootstrap helper treats nearly
    every non-completed item as `PENDING`, including restore operations
    that are already usable when an archive exists. Chroot is handled
    separately as `AVAILABLE`, so the menu currently mixes completion
    state and action availability inconsistently.
-   **Required semantics:**
    -   `PENDING` --- a required prerequisite or required build result
        is not yet satisfied.
    -   `AVAILABLE` --- the action can be run now, but running it is
        optional/repeatable and it is not a required completion gate.
    -   `COMPLETE` --- a build, verification, or archive requirement has
        been satisfied.
-   **Expected menu behavior:**
    -   Temporary toolchain build: `PENDING` -\> `COMPLETE`.
    -   Base-system build with temporary toolchain: `PENDING` -\>
        `COMPLETE`.
    -   Optional final rebuild (stage 3): `AVAILABLE` -\> `COMPLETE`;
        never `PENDING` solely because it was skipped.
    -   Verify completed base system: `PENDING` -\> `COMPLETE`.
    -   Create/compress base rootfs archive: `PENDING` -\> `COMPLETE`
        once a valid archive exists.
    -   Restore newest base rootfs archive: `AVAILABLE` whenever a valid
        archive exists; otherwise `PENDING`.
    -   Restore newest temporary toolchain archive: `AVAILABLE` whenever
        a valid toolchain archive exists; otherwise `PENDING`.
    -   Chroot into BFS rootfs: `AVAILABLE` when a usable rootfs exists;
        otherwise `PENDING`.
    -   Launch BFSOS installer: `AVAILABLE` when a valid base archive
        exists and a current installer is discoverable; otherwise
        `PENDING`.
-   **Implementation:** Replace the one-size-fits-all
    `_stage_complete_text` / `_dialog_stage_status` use with per-action
    status helpers or a generic status function that can distinguish
    completion checks from availability checks.
-   **Consistency:** Text-mode and Dialog menus must report the same
    status for every option.
-   **Regression test:** Test a clean tree, completed stage 1 only,
    completed stage 2, skipped stage 3, verified base, archive present,
    restored rootfs, restored toolchain, and installer-ready states.
    Confirm each menu item uses exactly the expected `PENDING`,
    `AVAILABLE`, or `COMPLETE` label.

## r32 Tracker Update

-   **Generated:** 2026-08-11
-   **Tracker-only update:** No bootstrap or installer code changed in
    this revision.
-   **Updated #66:** Defined exact `PENDING`, `AVAILABLE`, and
    `COMPLETE` semantics for the streamlined bootstrap/install workflow.
-   **Added #69:** Normalize status logic in both text and Dialog
    bootstrap menus, especially optional stage 3, restore actions,
    chroot, and installer launch.

### 70. Offer ZRAM swap when no disk swap is configured

-   [x] Enhancement
-   **Implemented in r35:**
    `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or
    `bootstrap.sh` as applicable.
-   **Area:** Installer storage / swap configuration
-   **Trigger:** After storage assignment is complete, detect whether
    the installed system has a configured swap partition or swap logical
    volume.
-   **No-swap behavior:** If no disk-backed swap is configured, ask
    whether the user wants to enable ZRAM swap on the installed BFSOS
    system.
-   **Prompt:** Clearly explain that ZRAM provides compressed swap in
    RAM and does not require a swap partition.
-   **Default:** Yes when no other swap exists, while still requiring
    the user to confirm the choice.
-   **Existing-swap behavior:** If disk-backed swap exists, do not
    silently enable ZRAM. Either skip the ZRAM prompt or present ZRAM
    separately as an optional supplemental swap choice.
-   **Kernel validation:** Before configuring ZRAM, verify the target
    kernel/config/modules provide ZRAM support (for example built-in
    `CONFIG_ZRAM=y` or module `CONFIG_ZRAM=m` with the corresponding
    module installed). Do not assume support from the live environment.
-   **Configuration:** Install/write the appropriate BFSOS/systemd ZRAM
    configuration so ZRAM swap is created automatically during normal
    boot.
-   **Failure behavior:** If the user selects ZRAM but the installed
    kernel or required userspace support is unavailable, show a clear
    warning/error and do not claim ZRAM is enabled.
-   **Review screen:** Explicitly show both disk swap and ZRAM state,
    for example `Disk swap: none` and `ZRAM swap: enabled`, so
    compressed swap is not hidden from the installation summary.
-   **Post-install verification:** Verify the installed configuration
    exists and is enabled before declaring the ZRAM setup successful.
-   **Regression test:** Test (1) no swap + ZRAM Yes, (2) no swap + ZRAM
    No, (3) disk swap configured, (4) ZRAM kernel support missing,
    and (5) reboot of a completed ZRAM-enabled install followed by
    `swapon --show`/equivalent verification.

## r33 Tracker Update

-   **Generated:** 2026-08-11
-   **Tracker-only update:** No installer/bootstrap code changed in this
    revision.
-   **Added:** #70 optional ZRAM swap configuration when no disk-backed
    swap is selected, including target-kernel validation, review
    visibility, boot-time configuration, and post-install verification.

### 71. Keep final GRUB verification consistent with generated storage arguments

-   [x] Fix
-   **Implemented in r35:**
    `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh` and/or
    `bootstrap.sh` as applicable.
-   **Area:** Final installation validation / success transition
-   **Observed behavior:** r27 generated explicit `rd.md.uuid=`
    arguments, then aborted the installation because the verifier still
    required `rd.auto`. This prevented the normal
    successful-installation Chroot/Finish menu from appearing.
-   **Desired behavior:** The final verifier must validate exactly the
    storage arguments the generator intentionally emits. Do not require
    obsolete/alternative arguments that are not part of the chosen
    generation strategy.
-   **Failure reporting:** When validation fails, clearly state which
    expected argument/value is missing or malformed. For MD RAID, print
    the expected complete UUID and the actual generated kernel line.
-   **Success transition:** Only after final GRUB/initramfs verification
    succeeds should the installer show the Installation Complete dialog
    and the Chroot/Finish menu.
-   **Logging:** Keep logging active through final verification and the
    post-install transition so any late failure is captured in the
    installer log.
-   **Regression test:** Test successful and intentionally broken
    RAID/LUKS/LVM cmdlines. Broken configuration must fail with an
    actionable message; correct configuration must pass and reach the
    post-install menu.

## r34 Tracker Update

-   **Generated:** 2026-08-11
-   **Tracker-only update:** No installer/bootstrap code changed in this
    revision.
-   **Reopened/expanded #57:** r27 truncated colon-separated MD UUIDs,
    omitted explicit LUKS UUID arguments for the tested topology, and
    used a stale verifier that still required `rd.auto`.
-   **Added #71:** Keep final GRUB verification synchronized with
    generated storage arguments and preserve logging through the final
    validation/post-install transition.
-   **Test conclusion:** The missing Chroot/Finish menu was a
    consequence of final GRUB verification failure, not a standalone
    menu bug.

## r35 Implementation Pass

-   **Generated:** 2026-08-11

-   **Installer moved for normal workflow:**
    `scripts/install-bfs-menu-v50-tracker-fixed-r35.sh`

-   **Bootstrap:** `bootstrap.sh`

-   **Implemented:** #57, #58, #62, #63, #64, #65, #66, #67, #69, #70,
    #71.

-   **#54:** Installed-system safeguard implemented; source
    `aaa_filesystem/Pkgfile` remains pending because that port file was
    not supplied in this pass.

-   **GRUB fix:** Full colon-separated MD UUIDs are preserved, explicit
    LUKS UUIDs come from finalized crypttab, and verification no longer
    requires stale `rd.auto`/`rd.md=1`.

-   **Bootstrap/install handoff:** Bootstrap discovers the newest
    executable versioned installer under `scripts/` and hands it the
    newest valid base archive.

-   **Normal bootstrap path:** stages 1, 2, 4, and rootfs archive
    creation are required; stage 3 is optional and reports AVAILABLE
    until completed.

-   **Package policy:** every install performs `ports -u` followed by
    mandatory `prt-get sysup`; optional packages are installed
    afterward.

-   **Post-install cleanup:** user is asked whether to clear
    `/var/cache/pkg/packages/*`; default is No.

-   **Swap policy:** when no disk swap is selected, installer offers
    ZRAM (default Yes) and validates installed-kernel ZRAM support
    before enabling its systemd service. \## r38 Tracker Update

-   **Generated:** 2026-08-11

-   **Bootstrap:** `bootstrap.sh` through r42

-   **Installer:** no installer code changed in this tracker update.

-   **Bootstrap changes below are completed and regression-tested
    interactively in the VM unless otherwise noted.**

### 72. Fix bootstrap theme Settings workflow and defaults

-   [x] UI / workflow fix
-   **Implemented in:** `bootstrap.sh`
-   **Area:** Bootstrap Settings / interface themes
-   **Default theme:** Classic Slackware is the startup default on every
    normal bootstrap invocation. A stale saved theme from an earlier
    test must not silently make Debian or another theme the startup
    default.
-   **Theme choices:** The bootstrap Settings theme selector now exposes
    all supported themes in one place:
    -   `Slackware` --- Classic Slackware theme and default.
    -   `Debian` --- Classic Debian installer/newt-style theme.
    -   `Monochrome`.
    -   `Midnight`.
    -   `Light`.
-   **Visible theme labels:** Capitalize the first character of every
    left-hand theme name. Use `Debian`, not the internal identifier
    `classic`, as the visible label.
-   **Internal compatibility:** The Debian palette may continue to use
    the existing internal `classic` theme key so the underlying
    implementation does not need to be renamed.
-   **Back behavior:** Back/Esc from the theme selector returns cleanly
    to the previous/bootstrap menu. Navigating Settings must not produce
    `Operation completed successfully` or a
    `Press Enter to return to the menu...` pause.
-   **Settings layout:** The main bootstrap menu shows only `Settings`,
    with no current-theme text on the right-hand side so additional
    settings can be added later without changing the main-menu layout.
-   **Menu placement:** `Settings` is no longer a numbered/scrollable
    menu entry. It is a dedicated bottom dialog button positioned
    between `<Select>` and `<Quit>`.
-   **Regression test:** Start bootstrap with no special environment
    override, confirm Classic Slackware is selected by default, open
    Settings, verify all five themes and capitalization, apply each
    theme, use Back/Esc, and confirm the main menu returns immediately
    without an operation-success/pause screen.

### 73. Use AVAILABLE / NOT AVAILABLE for bootstrap chroot status

-   [x] UI / workflow fix
-   **Implemented in:** `bootstrap.sh`
-   **Area:** Bootstrap main-menu status
-   **Observed behavior:** Chroot was shown as `PENDING`, which
    incorrectly implied it was an unfinished required stage.
-   **Desired behavior:** Chroot is an optional action and must display
    only:
    -   `AVAILABLE` when a usable restored BFSOS environment exists.
    -   `NOT AVAILABLE` when it cannot currently be entered.
-   **Availability gate:** Do not mark chroot available merely because a
    base archive or toolchain archive exists. Require that the base
    rootfs and/or temporary toolchain has actually been restored into
    the working tree and that a usable Bash exists in the rootfs.
-   **Consistency:** Apply the same wording and availability logic to
    both Dialog and text-mode bootstrap menus.
-   **Regression test:** With only archives present, verify Chroot shows
    `NOT AVAILABLE`; restore the base rootfs or temporary toolchain as
    appropriate and verify it changes to `AVAILABLE` only when the
    restored filesystem is actually usable.

### 74. Match installer theme-name capitalization to bootstrap

-   [x] UI consistency fix
-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r36.sh`.
    Theme selector now shows `Slackware`, `Debian`, `Monochrome`,
    `Midnight`, and `Light`, with Slackware first/default and internal
    `classic` compatibility preserved.
-   **Area:** Installer Settings / interface themes
-   **Observed behavior:** Bootstrap now presents the left-hand theme
    names as `Slackware`, `Debian`, `Monochrome`, `Midnight`, and
    `Light`, while the installer still needs the same visible naming
    convention.
-   **Desired behavior:** Update the installer theme-selection UI to use
    the same capitalization and user-facing names as `bootstrap.sh`.
-   **Required visible names:** `Slackware`, `Debian`, `Monochrome`,
    `Midnight`, `Light`.
-   **Debian naming:** Show `Debian` in the selector rather than
    exposing an internal theme key such as `classic`; descriptions may
    still identify it as the Classic Debian installer/newt-style theme.
-   **Default:** Classic Slackware remains the installer default.
-   **Compatibility:** Preserve internal theme keys/profile
    compatibility where practical; this is a display-name/UI consistency
    change, not a requirement to rename stored identifiers.
-   **Regression test:** Compare installer and bootstrap theme selectors
    side-by-side and confirm theme names, capitalization, order/default
    behavior, and descriptions are consistent. \### 75. Return directly
    to bootstrap after installer exits
-   [x] UI / workflow fix
-   **Implemented in:** `bootstrap-r44-tracker-complete.sh`. Returning
    from the installer now resets the terminal and immediately redraws
    bootstrap with no generic success/failure message or Enter pause.
-   **Area:** Bootstrap-to-installer handoff / return behavior
-   **Observed behavior:** After the installer exits back to
    `bootstrap.sh`, bootstrap currently shows:
    -   `Operation completed successfully.`
    -   `Press Enter to return to the menu...`
-   **Desired behavior:** When the installer exits normally or is
    cancelled and control returns to bootstrap, immediately redraw and
    return to the bootstrap main menu.
-   **Do not show:** No generic `Operation completed successfully.`
    message and no `Press Enter to return to the menu...` pause for the
    installer-launch action.
-   **Scope:** This exception applies specifically to the
    `Launch BFSOS installer` menu action. Normal build stages may
    continue to show completion/failure output and pause when that
    output is useful.
-   **Terminal handling:** Restore/reset the terminal cleanly after the
    installer exits before redrawing the bootstrap menu so no installer
    colors, background, cursor state, or stale screen content remain.
-   **Regression test:** Launch the installer from bootstrap, then test
    both normal installer exit and Cancel/Back/Quit paths. In every
    case, confirm control returns immediately to the bootstrap main menu
    with no intermediate success/pause screen.

### 76. Move Bootstrap Settings to bottom action-button row

-   [x] UI / workflow fix
-   **Implemented in:** `bootstrap.sh` r43
-   **Area:** Bootstrap main menu
-   **Observed behavior:** `Settings` was incorrectly added as a
    numbered item at the bottom of the scrollable bootstrap menu.
-   **Desired behavior:** Remove `Settings` from the numbered menu
    entries and place it on the bottom action-button row between
    `Select` and `Quit`.
-   **Final dialog button order:** `<Select>` `<Settings>` `<Quit>`.
-   **Behavior:** Selecting the Settings button opens the existing
    Bootstrap Settings / Interface Theme screen; returning from Settings
    redraws the bootstrap main menu normally.
-   **Compatibility:** Text-mode fallback retains the numeric Settings
    choice because it has no dialog button row.
-   **Status:** Completed in bootstrap r43.

### 77. Silently return when Chroot is NOT AVAILABLE

-   [x] UI / workflow fix

-   **Implemented in:** `bootstrap-r44-tracker-complete.sh`. Selecting
    Chroot while unavailable now immediately redraws the menu; no
    root-stage call, error, success message, or pause is produced.

-   **Area:** Bootstrap main menu / Chroot action

-   **Observed behavior:** When `Chroot into BFS rootfs` shows
    `NOT AVAILABLE`, pressing Enter on that menu item currently proceeds
    into the action path and produces an error/message before returning.

-   **Desired behavior:** If Chroot is `NOT AVAILABLE`, selecting it
    should do nothing except immediately redraw the bootstrap main menu.

-   **Do not show:** No error message, no `Operation failed`, no
    `Operation completed successfully`, and no
    `Press Enter to return to the menu...` pause.

-   **Availability logic:** Continue using the existing
    `_chroot_available` test. The menu action should check availability
    before invoking the root/chroot stage.

-   **Available behavior:** When Chroot shows `AVAILABLE`, Enter should
    continue to launch the chroot normally.

-   **Regression test:** With Chroot showing `NOT AVAILABLE`, highlight
    it and press Enter; confirm the bootstrap menu immediately redraws
    with no intermediate output or pause. Then restore a usable
    rootfs/toolchain, confirm it changes to `AVAILABLE`, and verify
    Enter launches the chroot normally. \### 78. Rescan all storage
    after every destructive or topology-changing storage operation

-   [x] Installer storage-detection bug

-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r36.sh`.
    Added centralized `refresh_storage_state()` and wired it into cfdisk
    return, storage metadata destruction, RAID assembly/create/signature
    wipe, LUKS create/open/close, LVM PV/VG/LV creation, and
    filesystem/swap formatting.

-   **Area:** Installer storage discovery / partitioning / filesystems /
    RAID / LUKS / LVM

-   **Observed behavior:** Possible stale-device-state bug: after
    launching `cfdisk` from inside the installer and creating or
    changing partitions, the RAID member selection screen appeared not
    to reflect the newly written partition table.

-   **Expanded requirement:** Do not limit the fix to `cfdisk`. After
    every destructive or storage-topology-changing operation, force a
    fresh kernel/userspace storage rescan and rebuild the installer's
    device inventory before presenting another storage-selection or
    review screen.

-   **Operations that must trigger a rescan include at minimum:**

    -   returning from `cfdisk` or another partition-table editor after
        changes;
    -   creating, deleting, resizing, or rewriting partitions/partition
        tables;
    -   formatting or reformatting filesystems and initializing swap;
    -   creating, assembling, stopping, destroying, or otherwise
        changing MD RAID arrays;
    -   creating, opening, closing, formatting, or otherwise changing
        LUKS mappings;
    -   creating/removing/changing LVM PVs, VGs, and LVs;
    -   destructive signature/wipe operations such as `wipefs`;
    -   any other installer action that changes block-device names,
        mappings, filesystem/type metadata, sizes, parent/child
        relationships, or availability.

-   **Refresh sequence:** Review use of `partprobe`,
    `blockdev --rereadpt`, `udevadm settle`, MD/LUKS/LVM discovery
    commands, and/or equivalent safe mechanisms as appropriate for the
    operation. The goal is a reliable fresh view of all storage devices,
    not merely the disk that was just edited.

-   **No stale cache:** Do not reuse a partition/device list gathered
    before the destructive operation. Re-run the installer
    storage-enumeration logic (`lsblk` and any RAID/LUKS/LVM discovery
    used by the installer) after the rescan.

-   **Consumers of refreshed state:** RAID member selection,
    filesystem/format selection, mount-point assignment, swap selection,
    LUKS, LVM, installation review, and every later storage screen must
    use the refreshed inventory.

-   **Failure handling:** If the kernel cannot reread a partition table
    or refresh a device because it is busy, clearly report the condition
    rather than silently continuing with stale information.

-   **Regression test:** Exercise each supported
    destructive/topology-changing storage path, then immediately enter
    the next relevant storage screen and verify device names,
    partitions, sizes, filesystem/type information, RAID/LUKS/LVM
    mappings, and availability match the new state without restarting
    the installer. \### 79. Verify sudo default uses password
    authentication

-   [x] Installer configuration verification

-   **Verified in source:** The installer default remains
    `SUDO_MODE=password`, which writes `%wheel ALL=(ALL:ALL) ALL`.
    `NOPASSWD` is only written when the user explicitly selects the
    no-password mode, matching the successful VM test.

-   **Area:** Installed-system sudo / privilege escalation defaults

-   **Check:** Confirm that the installer installs and configures `sudo`
    as the default privilege-escalation mechanism for regular users.

-   **Required default:** `sudo` must require the invoking user's
    password by default.

-   **Do not default to:** Passwordless `NOPASSWD` sudo access.

-   **Configuration review:** Check `/etc/sudoers` and any
    installer-created files under `/etc/sudoers.d/` to make sure the
    regular-user/admin group rule uses normal password authentication
    and that no broader `NOPASSWD` rule overrides it.

-   **Validation:** Run `visudo -c` on the installed system and test
    from a regular configured user with a cleared sudo timestamp
    (`sudo -k`) to confirm the next `sudo` command prompts for that
    user's password.

-   **Regression test:** Fresh install with a normal user, log in as
    that user, run `sudo -k` followed by a harmless sudo command, and
    verify a password prompt appears and valid user credentials are
    required. \### 80. Make Review (option 10) flow directly into Ready
    to install (option 11)

-   [x] Installer UI / workflow fix

-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r36.sh`.
    Option 10 Review now advances directly to Ready to install; Back
    from Ready reopens Review; Continue starts installation without
    returning to the main menu.

-   **Area:** Installer main menu options 10 and 11 / final pre-install
    workflow

-   **Observed behavior:** Option 10 (`Review selections`) displays the
    installation review, but pressing `Continue` returns to the
    installer main menu instead of advancing to the final installation
    confirmation.

-   **Correct workflow:** Options 10 and 11 should behave as one
    continuous pre-install sequence:

    1.  Select option 10 and display the complete `Review selections`
        screen.
    2.  Press `Continue` on the review screen.
    3.  Advance directly to the option 11 `Ready to install` screen
        (`Begin the BFS installation?`).
    4.  Press `Continue` there to begin installation.
    5.  Press `Back` on `Ready to install` to return directly to the
        `Review selections` screen.

-   **Review-screen behavior:** The important fix is not to send
    `Continue` back to the main menu. `Continue` must advance to
    `Ready to install`.

-   **Main-menu option 11:** Directly selecting option 11 may continue
    to open the `Ready to install` stage, but the normal intended path
    is Review -\> Ready to install -\> Install.

-   **No state loss:** Moving forward or backward between Review and
    Ready to install must preserve all current installer selections.

-   **Regression test:** Enter option 10, review selections, press
    `Continue`, verify `Ready to install` appears immediately; press
    `Back`, verify the same review reappears; press `Continue` again and
    then `Continue` on Ready to install, and verify installation begins
    without returning to the main menu between these stages. \### 81.
    Exit directly to terminal after installation is finished

-   [x] Installer UI / workflow cleanup

-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r36.sh`.
    Removed the redundant final completion/unmount text and terminal
    review dump; Finish restores terminal state and returns directly to
    the caller while normal cleanup remains active.

-   **Area:** Installer completion / final exit

-   **Observed behavior:** After the installation has completed and the
    user finishes the post-install/chroot workflow, the installer still
    prints an extra completion/unmount message instead of simply
    returning control to the shell.

-   **Desired behavior:** Once installation is complete and the user
    chooses to finish/exit, perform the required cleanup and unmount
    operations, restore the terminal state, and return directly to the
    live-environment terminal prompt.

-   **Do not show:** No extra final `BFS installation completed...`
    message, no generic success message, and no `Press Enter` pause
    after the user has already finished the installation workflow.

-   **Keep:** The existing completion/post-install screen may still
    provide the explicit choices to chroot into the installed system or
    finish the installation; this issue concerns what happens after the
    user chooses to finish.

-   **Implementation note:** The current installer path explicitly
    prints
    `BFS installation completed. The installer will unmount the target filesystems.`
    after the post-install menu; remove that redundant final output
    while preserving cleanup/unmount behavior.

-   **Regression test:** Complete an installation, use the post-install
    chroot option if desired, exit the chroot, then choose Finish.
    Confirm filesystems are cleaned up/unmounted and control returns
    directly to the live shell prompt with no additional completion
    dialog/message or pause. \### 82. Fix `bfs-zram.service` systemd
    ordering cycle

-   [x] Installer / installed-system boot fix

-   **Implemented in:** `install-bfs-menu-v50-tracker-fixed-r36.sh`.
    Generated ZRAM service now uses `DefaultDependencies=no`; default
    ZRAM capacity is dynamically set to 2× physical RAM. The ordering
    fix was also validated manually in the VM: ZRAM active and
    `systemctl is-system-running` returned `running`.

-   **Area:** ZRAM swap / systemd unit ordering

-   **Observed on first successful installed-system boot:**
    `bfs-zram.service` itself starts successfully and creates the
    configured ZRAM swap, but systemd reports an ordering cycle
    involving `tmp.mount`, `swap.target`, `bfs-zram.service`,
    `basic.target`, and `sysinit.target`. The cycle can cause
    `tmp.mount` to be dropped from the boot transaction and leaves
    `systemctl is-system-running` reporting `degraded`.

-   **Current generated unit:** `bfs-zram.service` uses
    `After=systemd-modules-load.service`, `Before=swap.target`, and
    `WantedBy=swap.target`, while normal service default dependencies
    also place it after `basic.target`/`sysinit.target`. Because
    `tmp.mount` is `After=swap.target` and participates in the early
    local-filesystem ordering, this produces a dependency cycle.

-   **Required fix:** Make the ZRAM setup service an explicitly early
    boot service by adding `DefaultDependencies=no` while retaining the
    required module-load ordering and `Before=swap.target` relationship.
    Keep it enabled from `swap.target`.

-   **Target unit shape:**

    ``` ini
    [Unit]
    Description=BFSOS compressed ZRAM swap
    DefaultDependencies=no
    After=systemd-modules-load.service
    Before=swap.target

    [Service]
    Type=oneshot
    RemainAfterExit=yes
    ExecStart=/usr/libexec/bfs-zram-setup
    ExecStop=/usr/libexec/bfs-zram-stop

    [Install]
    WantedBy=swap.target
    ```

-   **Default ZRAM sizing:** Set the default ZRAM device size to **2×
    the system's physical RAM**. Example: a system with 32 GiB RAM
    should default to a 64 GiB `/dev/zram0`.

-   **Sizing implementation:** Calculate the size dynamically from
    detected physical memory rather than hard-coding a fixed size. Keep
    any explicit user-configured size override if the installer/settings
    already provide one.

-   **Do not regress:** ZRAM must still be initialized before
    `swap.target` is considered reached, `/dev/zram0` must become active
    swap, and shutdown must still cleanly stop the service.

-   **Regression test:** Fresh install with ZRAM enabled, cold boot,
    confirm there are no `Found ordering cycle` messages for
    ZRAM/swap/tmp, `tmp.mount` is not dropped because of the ZRAM unit,
    `systemctl status bfs-zram.service` is successful, `swapon --show`
    lists the configured ZRAM device at approximately 2× physical RAM by
    default, and `systemctl is-system-running` is not degraded because
    of this ordering issue. \### 83. Diagnose/fix VM reboot not
    returning after `reboot`

-   [x] Boot / VM integration bug

-   **Root cause found / host fix applied:** The VM launcher contained
    QEMU `-no-reboot`, which intentionally exits QEMU on guest reboot.
    The option was removed from the live launcher and its shell syntax
    was checked. This is a VM-launcher issue, not a BFSOS guest/GRUB
    defect; one reboot regression test remains to confirm behavior.

-   **Area:** Installed BFSOS reboot behavior under QEMU

-   **Observed behavior:** The installed BFSOS VM boots successfully
    from a cold start, but issuing `reboot` from the running installed
    system does not bring the VM back up normally/visibly. The VM
    appears to disappear or fail to return after shutdown/reboot.

-   **Important distinction:** Cold boot from the VM launcher works, so
    this is not currently evidence of a GRUB/initramfs/root-filesystem
    boot failure. The problem appears specific to the reboot path and
    may involve guest shutdown/reboot handling, QEMU launcher options,
    firmware/UEFI reset behavior, or the installed system's reboot
    mechanism.

-   **Investigation:** Determine whether QEMU exits completely on guest
    reboot, remains running but loses display/network, or resets and
    then fails during the next firmware/boot sequence. Inspect the
    launcher command line and QEMU log after reproducing the issue.

-   **Checks:** Review QEMU options such as `-no-reboot`,
    shutdown/reboot handling, background process supervision, SPICE
    lifecycle, UEFI/OVMF behavior, and whether the launcher
    intentionally exits when the guest requests reboot.

-   **Guest-side checks:** Inspect the previous boot journal
    (`journalctl -b -1`) after the next successful cold start for
    shutdown/reboot errors, and verify systemd reached the expected
    reboot target cleanly.

-   **Do not conflate with installer boot success:** The first cold boot
    already proved that GRUB, initramfs, LUKS, MD RAID, LVM, Btrfs,
    separate `/usr`, `/opt`, `/var`, `/home`, and EFI boot all work from
    a powered-off VM.

-   **Regression test:** Boot the installed VM, issue `reboot`, and
    confirm the same QEMU process successfully resets and returns to the
    BFSOS boot/login prompt without manually restarting the VM launcher.

## r48 Tracker Update

-   **Generated:** 2026-08-11
-   **Bootstrap implementation:** `bootstrap-r44-tracker-complete.sh`
-   **Installer implementation:**
    `install-bfs-menu-v50-tracker-fixed-r36.sh`
-   **Tracker status:** All currently listed code/configuration changes
    through issue 83 have been applied. Items whose final proof requires
    another install/reboot remain noted as regression tests even though
    the requested code change is implemented.
-   **Validation performed:** Both updated shell scripts pass `bash -n`.
    Static checks confirm the new bootstrap short-circuit/return
    behavior, installer theme labels, storage refresh hooks, sudo
    password default, Review -\> Ready flow, clean final exit, and ZRAM
    service/sizing changes.

### Bootstrap Stage 1/2 UTF-8 locale archive for temporary toolchain --- GCC 16.2 extraction blocker

-   [x] **ROOT CAUSE CONFIRMED / PERMANENT CODE FIX IMPLEMENTED;
    fresh-build regression pending (2026-08-18):** Bootstrap Stage 2 GCC
    16.2 extraction failed in temporary-toolchain `bsdtar` because
    temporary glibc lacked its own usable UTF-8 locale archive.
-   **Root cause:** Stage 2 is still using `/tmp/lfs-tools/bin/pkgmk`
    and `/tmp/lfs-tools/bin/bsdtar`. Those binaries use the temporary
    glibc in `/tmp/lfs-tools/lib/libc.so.6`, whose compiled locale paths
    point at `/tmp/lfs-tools/lib/locale/locale-archive` and
    `/tmp/lfs-tools/lib/locale`. Generating `C.utf8` only in the target
    rootfs `/usr/lib/locale/locale-archive` therefore does not make
    UTF-8 available to temporary-toolchain `bsdtar`.
-   **Observed proof:** Target `locale -a` reported `C.utf8` and target
    `LC_ALL=C.utf8 locale charmap` reported `UTF-8`, while
    temporary-toolchain `bsdtar` still reported
    `Failed to set default locale`.
    `strings /tmp/lfs-tools/lib/libc.so.6` confirmed its locale archive
    path is `/tmp/lfs-tools/lib/locale/locale-archive`.
-   [x] **Stage 1 permanent fix implemented:**
    `ports/core/glibc/Pkgfile` now generates the temporary toolchain
    `C.UTF-8` locale with the temporary `localedef` and validates
    `LC_ALL=C.utf8 ... locale charmap` before glibc bootstrap completes;
    `bootstrap.sh` verifies the archive exists and is usable before
    Stage 1 is archive-ready.
-   [x] **Stage 1 archive requirement implemented:** the normal
    toolchain archive includes `/tmp/lfs-tools`, and Stage 1 now
    explicitly rejects an archive that lacks
    `./tmp/lfs-tools/lib/locale/locale-archive`.
-   [x] **Stage 2 target-glibc fix implemented:** immediately after
    target glibc is installed, `bootstrap.sh` generates `C.UTF-8` with
    target `/usr/bin/localedef` and validates that target `C.utf8`
    reports `UTF-8` before continuing.
-   [x] **pkgmk environment policy implemented:** generated
    package-build configs/chroot calls no longer force plain C over
    `pkgmk` locale selection; non-package deterministic helper
    operations may still use C.
-   [x] **pkgmk detection hardening implemented in pkgutils release 10
    and initial-bootstrap patch:** locale selection now checks both
    locale enumeration and an actual `locale charmap` call, preferring
    the temporary-toolchain locale command when the running `pkgmk` is
    under `/tmp/lfs-tools`.
-   **Manual workaround result:** After generating the UTF-8 locale for
    the temporary toolchain, GCC 16.2 successfully extracted; the
    previous UTF-8 pathname errors disappeared. This confirms the
    locale-path/toolchain mismatch as the extraction failure's cause.
-   [x] **Regression test --- fresh Bootstrap 1 / effective runtime
    proof PASSED 2026-08-18:** the clean Stage 1 temporary toolchain
    proceeded into Stage 2 with the temporary UTF-8 locale fix in place;
    Stage 2 temporary-toolchain bsdtar subsequently extracted GCC 16.2
    successfully. The explicit archive-path check remains in Bootstrap
    code.
-   [x] **Regression test --- Bootstrap 2 PASSED 2026-08-18:** GCC 16.2
    extracted successfully during the clean Stage 2 run without the
    previous pathname-conversion failure.
-   [ ] **Regression test --- archive restore:** Restore a freshly
    created Stage 1 toolchain archive and repeat the temporary `bsdtar`
    UTF-8 test before beginning Stage 2.
-   [ ] **Regression test --- Stage 3/final system:** Verify the
    target/final `C.utf8` locale remains usable after glibc/pkgutils
    rebuild and final-system `bsdtar` can extract the GCC source without
    locale/pathname errors.

## r98 Tracker Update

-   **Generated:** 2026-08-19
-   **Scope:** Bootstrap/package infrastructure follow-up from the fresh
    Stage 2 rebuild, plus small bootstrap UI cleanup and
    installer-recovery notes observed during the same test cycle.
-   **Status policy:** Items that were fixed during this test are marked
    implemented/verified where the actual retry passed; follow-up
    hardening and UI-only items remain open until changed and
    regression-tested.

### 84. Distinguish bootstrap `AVAILABLE` visually from `COMPLETE`

-   [x] **IMPLEMENTED in bootstrap r59 / runtime visual regression
    pending --- UI cleanup**
-   **Area:** `bootstrap.sh` main-menu status colors
-   **Observed behavior:** `[AVAILABLE]` currently uses the same green
    status color as `[COMPLETE]`, so optional/repeatable actions can
    look finished rather than merely usable.
-   **Desired behavior:** Keep `[COMPLETE]` green, change `[AVAILABLE]`
    to a clearly different color such as cyan, keep `[PENDING]` red, and
    retain the existing exit/accent color for `[EXIT]`.
-   **Scope:** Apply the color distinction consistently to Stage 3,
    restore actions, Chroot, installer launch, and any other status that
    uses `AVAILABLE` in both Dialog and text-mode output where colors
    are supported.
-   **Semantics:** Do not change the already-defined meaning of
    `AVAILABLE`; this is only a visual distinction from `COMPLETE`.
-   **Regression test:** Exercise the bootstrap menu with a mix of
    completed, available, pending, and exit states and confirm no
    available action is rendered with the same green color as a
    completed stage.

### 85. `prt-utils` upstream archive download blocked by CRUX Anubis/login layer

-   [x] Packaging/source fix --- implemented and Stage 2 retry passed
-   **Area:** `ports/core/prt-utils`
-   **Observed failure:** The CRUX
    `git.crux.nu/tools/prt-utils/archive/...tar.gz` URL redirected to
    `/user/login` and ultimately returned HTML from the Anubis/login
    layer instead of a tar archive. `pkgmk` accepted the downloaded body
    and `bsdtar` later failed with `Unrecognized archive format`.
-   **Confirmed behavior:** Both the pinned-commit archive URL and the
    official `release-1.3.7.tar.gz` archive URL were affected, while a
    normal anonymous `git clone https://git.crux.nu/tools/prt-utils.git`
    still worked.
-   **Implemented workaround:** Vendor the verified
    `prt-utils-release-1.3.7.tar.gz` source directly under
    `ports/core/prt-utils/` and use it as a local port source instead of
    relying on the protected archive endpoint.
-   **Pkgfile cleanup:** Keep the port on the new automatic build path
    and retain only the `post_build()` action needed to create
    `$PKG/etc/revdep.d`; no package-specific `pkg_build()` is required
    for the normal Makefile build.
-   **Regression result:** After the pkgutils local-source detection fix
    in #86, Bootstrap Stage 2 successfully rebuilt `prt-utils` from the
    vendored archive.
-   **Follow-up:** Revisit the source location if CRUX restores
    anonymous archive access or provides a stable official mirror; do
    not depend permanently on a temporary third-party mirror.

### 86. pkgutils extension must build local/vendored archives without requiring a source-cache copy

-   [x] Core package-build fix --- implemented and verified by
    `prt-utils` Stage 2 retry
-   **Area:** `ports/core/pkgutils/extension`
-   **Root cause:** The generic build extension successfully let `pkgmk`
    extract a local port archive into its work tree, but
    source-directory detection later attempted to reopen the archive
    from `$PKGMK_SOURCE_DIR`. Local/vendored sources are not guaranteed
    to exist in `/var/cache/pkg/sources`, so `srcdir` became empty and
    automatic build-type detection ran one directory too high.
-   **Observed trace:** `prt-utils` extracted into the pkgmk work tree,
    then
    `bsdtar -tf /var/cache/pkg/sources/prt-utils-release-1.3.7.tar.gz`
    failed because that cache file did not exist; `detect_buildtype`
    therefore could not see `prt-utils/Makefile`.
-   **Implemented fix:** Source-directory detection now prefers the
    conventional `$name-$version` directory and otherwise inspects the
    already-extracted work tree. If exactly one top-level extracted
    directory exists, the extension enters it; if multiple top-level
    directories exist, it refuses to guess.
-   **Design rule:** Once `pkgmk` has already extracted the source, the
    extension should determine where the extracted source tree is rather
    than requiring knowledge of where the original archive was stored.
-   **Package revision:** `pkgutils` was bumped to `5.40.12-12` for the
    extension change.
-   **Regression result:** Bootstrap Stage 2 retried `prt-utils`,
    correctly entered the extracted `prt-utils/` directory, detected its
    Makefile, and completed the build.
-   **Future regression tests:** Test at least one normal downloaded
    `$name-$version` archive, one local archive whose top-level
    directory differs from `$name-$version`, and one deliberately
    multi-directory archive to verify the no-guess failure path.

### 87. Harden `pkgmk` download validation against HTML/login/error bodies masquerading as archives

-   [ ] Package-download hardening
-   **Area:** pkgutils / `pkgmk` source download path
-   **Observed behavior:** The CRUX Anubis/login response ultimately
    returned HTTP success with `Content-Type: text/html`, so the
    downloader treated the body as a successful `.tar.gz` source and
    only failed later during extraction.
-   **Desired behavior:** Fail at download/validation time when an
    archive URL resolves to a login/error/HTML response rather than a
    valid source archive. Preserve the URL and response context in the
    package log.
-   **Implementation options to review:** use curl failure handling for
    HTTP errors/redirect loops, inspect final response metadata where
    practical, and/or validate archive sources with `bsdtar -tf` before
    accepting them into the source cache.
-   **Safety:** Do not reject legitimate text sources/patches/scripts
    merely because they are text; validation should be source-type aware
    and strongest for archive extensions.
-   **Regression test:** Feed `pkgmk` an archive URL returning HTML with
    HTTP 200, an HTTP 404, a redirect to a login page, and a valid
    archive. The first three must fail during source acquisition with a
    clear message; the valid archive must continue normally.

### 88. Install the CRUX Git ports driver from the BFSOS `git` package

-   [x] Packaging fix implemented; installed-package regression pending
-   **Area:** `ports/opt/git`
-   **Background:** The remembered Git helper is a **ports repository
    driver**, not direct Git-source support for `pkgmk`/`prt-get`. CRUX
    installs it as `/etc/ports/drivers/git` from the Git package.
-   **Implemented change:** Add the CRUX `git` driver file to the BFSOS
    Git port sources and install it in `post_build()` with mode 0755 to
    `$PKG/etc/ports/drivers/git`.
-   **Package revision:** Git was bumped from release 1 to release 2 for
    the package-content change.
-   **Do not conflate:** This driver allows `ports` to use Git-backed
    ports repositories; it does not make arbitrary Pkgfile `source=()`
    entries clone Git repositories.
-   **Regression test:** Build/install the BFSOS Git package, verify
    `/etc/ports/drivers/git` exists and is executable, and test a
    disposable Git-backed ports collection without affecting the normal
    httpup collections.

### 89. Keep `prt-utils`, `prt-get`, `pkgutils`, and `ports` roles documented separately

-   [x] **DOCUMENTED in README during r121 --- Documentation /
    maintenance cleanup**
-   **Area:** package/ports architecture documentation
-   **Reason:** The similarly named packages are easy to confuse during
    maintenance.
-   **Document the roles:** `prt-utils` provides maintenance/helper
    utilities such as `revdep`; `prt-get` is the higher-level
    ports/package frontend; `pkgutils` provides lower-level
    `pkgmk`/`pkgadd`/package infrastructure; `ports` handles repository
    synchronization through drivers such as `httpup` and `git`.
-   **Goal:** Add a short architecture note to the
    ports/package-management documentation so future source/driver
    changes are made in the correct component.

### 90. Review `prt-utils` 1.3.7 changes after the emergency source fix

-   [x] **STATIC REVIEW COMPLETED in r106; installed-command runtime
    smoke test pending --- Package audit**

-   **Area:** `ports/core/prt-utils`

-   **Reason:** The immediate priority was restoring a reproducible
    Stage 2 build after the upstream archive endpoint became unusable.
    Because the package version changed, review the vendored source
    `CHANGES` file for updates to `revdep` and the other helper tools
    that may affect BFSOS integration.

-   **Checks:** Compare installed command set, any `revdep.d`
    expectations, configuration paths, dependency assumptions, and
    behavior changes against the previous BFSOS package.

-   **r106 review result:** Vendored `CHANGES` confirms 1.3.7 changes
    are maintenance/tooling updates: Markdown output for `portspage`,
    safer subshell sourcing in `dllist`, repository labeling in
    `prtcheckperms`, Cargo templates in `prtcreate`, whitelist updates
    in `prtverify`, and consolidated man-page documentation. No new
    runtime library path or mandatory service integration was
    identified. `/etc/revdep.d` remains required and BFSOS creates it.

-   **Current CRUX comparison:** CRUX also carries `prt-utils` 1.3.7 and
    installs `/etc/revdep.d`. BFSOS intentionally keeps the known-good
    1.3.7 source tarball vendored while the upstream Git archive
    endpoint is unreliable for non-browser package fetching.

-   **Regression test:** After installation, run the key `prt-utils`
    commands used by BFSOS maintenance and confirm expected
    output/paths.

### 91. Cold-resume installer should request LUKS passphrases after previous-install detection

-   [x] **IMPLEMENTED in r52-r57 / cold-recovery regression remains ---
    Installer recovery UX cleanup**
-   **Area:** cold-boot resume / storage reconstruction
-   **Observed behavior:** During a successful cold restore of a
    previous installation, the installer requested the LUKS passphrase
    before clearly presenting/detecting the previous-install resume
    state. The storage restore ultimately worked, but the prompt order
    felt backwards.
-   **Desired behavior:** First detect and explain that a previous
    incomplete/complete installation profile/storage stack was found,
    then tell the user which encrypted mappings need to be reopened, and
    only then request the required LUKS passphrase(s).
-   **Safety:** Do not weaken the existing non-destructive recovery
    logic; this is prompt ordering and context, not automatic passphrase
    storage or replay.
-   **Regression test:** Cold boot with a saved RAID/LUKS/LVM
    installation state, launch installer, verify previous-install
    detection appears before any passphrase request, unlock mappings,
    and confirm full storage recovery succeeds.

### 92. Revalidate installer cold-recovery status when the saved MD name differs from the kernel auto-assembled name

-   [x] Recovery bug fixed in current installer; keep regression
    coverage
-   **Area:** installer resume / MD identity
-   **Observed failure during earlier cold test:** Saved profile
    expected `/dev/md0`, while the live environment auto-assembled the
    same member set as `/dev/md127`. A naive resume attempt tried to
    assemble `/dev/md0` again and reported every member busy.
-   **Correct behavior:** Identify an already-active array by member/MD
    identity rather than requiring the saved transient `/dev/mdX` node
    name, then continue LUKS/LVM recovery without destructive
    reassembly.
-   **Regression result:** The subsequent installer revision
    successfully reconstructed the saved storage stack after cold boot.
-   **Regression test:** Repeat cold boot with kernel auto-assembly
    producing a different MD node name and confirm the installer
    recognizes/reuses the active array and reaches the installed target
    without reformatting or reassembling members destructively.

### 95. Show live LVM capacity information while creating PV/VG/LV layouts

-   [x] **IMPLEMENTED in installer r53; runtime regression pending ---
    Pre-1.0 LVM installer UX enhancement**
-   **Area:** storage configuration / LVM creation dialogs
-   **Priority:** Pre-1.0; medium priority
-   **Reason:** Advanced LVM layouts currently make it too easy to
    allocate storage without seeing the capacity context. This is
    especially noticeable with multiple PVs, one or more VGs, and
    multiple logical volumes.
-   **Desired PV display:** When selecting/creating physical volumes,
    show each selected PV/device and its usable size so the user can see
    how much storage is being contributed.
-   **Human-readable units:** All human-facing capacity values use
    automatically selected IEC units (`bytes`, `KiB`, `MiB`, `GiB`,
    `TiB`, etc.) rather than raw bytes or awkwardly huge MiB/GiB values.
-   **Desired VG display:** During VG creation and LV management, show
    the VG name, total size, allocated/used space, and remaining free
    space.
-   **Desired LV display:** Show existing logical volumes and their
    sizes while adding additional LVs. Before creating a new LV, clearly
    show the currently available VG free space.
-   **Size-expression UX:** If the installer supports values such as
    `%FREE`, `%VG`, or similar LVM percentage expressions,
    resolve/display the approximate resulting size before committing
    when practical.
-   **After-allocation feedback:** After an LV is created, refresh the
    displayed VG free-space value so subsequent allocations always use
    current information.
-   **Implementation note:** Prefer querying authoritative LVM state
    (`pvs`, `vgs`, `lvs` with machine-friendly output/units) rather than
    maintaining a separate installer-side capacity calculation when the
    LVM objects already exist.
-   **Scope for 1.0:** Keep this informational and low-risk. PV sizes,
    VG total/free/used capacity, existing LV sizes, and current
    remaining capacity are required; graphical capacity bars and other
    cosmetic visualization can wait until after 1.0.
-   **Regression tests:** Create an LVM layout using two PVs in one VG
    and several LVs; verify PV sizes are displayed correctly, VG
    total/free values update after every LV creation, existing LV sizes
    remain visible, and the installer prevents/handles an allocation
    larger than the remaining VG capacity cleanly.

### 104. Pre-1.0 full `ports/core` audit against current MLFS development, upstream, CRUX, and LFS/BLFS

-   \[\~\] **AUDIT STARTED in r106 --- Pre-1.0 package audit / core
    ports refresh**
-   **Area:** all BFSOS `ports/core` packages and their build
    instructions, patches, dependencies, source URLs,
    checksums/signatures, footprints, and installed integration.
-   **Reason:** Core has changed substantially during recent
    toolchain/base work. Before 1.0, perform a fresh package-by-package
    audit rather than assuming earlier LFS/CRUX comparisons are still
    current.
-   **Reference hierarchy:** use current **MLFS development** as the
    primary BFSOS multilib/toolchain/build-method reference; verify
    current release/security/build requirements against each package's
    authoritative upstream project; compare current CRUX core as an
    additional distro/package-layout reference; use ordinary LFS/BLFS
    development as secondary cross-checks where useful.
-   **For every core port, record/check:**
    -   BFSOS version/release versus current LFS/BLFS development, CRUX,
        and upstream stable/current appropriate release.
    -   Source URL availability and whether a more canonical/stable
        upstream URL exists.
    -   Required upstream/LFS/BLFS/CRUX patches and whether BFSOS
        carries obsolete, missing, or locally unnecessary patches.
    -   Configure/CMake/Meson/build flags and install commands against
        current upstream and LFS/BLFS guidance.
    -   Dependencies, optional dependencies intentionally
        enabled/disabled, bootstrap ordering, and circular-dependency
        risks.
    -   Correct BFSOS package naming, especially Python 3/module naming
        and other previously standardized conventions.
    -   Pkgfile archive-extension/source-directory handling and
        compatibility with current BFSOS pkgutils behavior.
    -   Installed files, symlinks, compatibility links, service/unit
        files, configuration defaults, permissions, ownership, and
        `.footprint` correctness.
    -   Security-relevant or ABI-impacting version changes that require
        rebuilds of dependent packages.
    -   Any CRUX-specific behavior BFSOS intentionally differs from;
        document the reason rather than blindly copying CRUX.
-   **Audit policy:** MLFS development is the primary
    multilib/build-method reference but is not a command to downgrade
    newer deliberate BFSOS maintenance releases. Upstream is
    authoritative for current releases/security/build requirements; CRUX
    and ordinary LFS/BLFS are comparison implementations. Preserve
    deliberate BFSOS design choices and document deviations.
-   **Current-reference note (2026-08-19):** MLFS development is
    continuously updated and must be read live at audit time. Current
    MLFS lists Linux 7.1.8 and explicitly permits the latest available
    stable kernel unless errata says otherwise. CRUX exposes its current
    core Pkgfiles for direct comparison. Re-check live versions at each
    audit pass instead of trusting search-index snapshots.
-   **Deliverable:** produce a package-by-package audit table/checklist
    showing BFSOS version, reference versions, source/patch/build
    differences, action required, and regression status. Apply changes
    in controlled batches so a bad update can be isolated.
-   **Regression:** after changes, perform a clean Bootstrap 1/2/3/base
    build, run package/footprint verification, boot a fresh base, and
    exercise installer-critical packages before declaring the audit
    complete.

### 105. Make installer elapsed/duration displays human-readable

-   [x] **IMPLEMENTED in installer r53 / pkgutils release 13; runtime
    regression pending --- Installer UX cleanup**
-   **Area:** install/build progress, completion summaries,
    package/build timing, and any other duration display
-   **Observed behavior:** Long-running operations can still display raw
    seconds such as `2841s`, which is difficult to read at a glance.
-   **Desired behavior:** Convert durations to a compact human-readable
    form throughout the installer rather than displaying large raw
    second counts.
-   **Examples:** `42s`; `4m 12s`; `47m 21s`; `1h 18m 09s`; include days
    if an operation ever exceeds 24 hours.
-   **Consistency:** Use one shared duration-formatting helper so
    progress screens, package/build summaries, final installation
    summaries, logs intended for humans, and other installer UI do not
    each format elapsed time differently.
-   **Precision:** Seconds-only is fine for short operations. For longer
    operations, show hours/minutes/seconds as appropriate without
    unnecessary zero-value units.
-   **Machine data:** Do not change machine-readable timestamps or raw
    timing values that scripts rely on; this requirement applies to
    human-facing output.
-   **Regression test:** Exercise short and long durations, including a
    value equivalent to `2841s`, and confirm it is rendered as `47m 21s`
    (or an equally clear consistent human-readable form) everywhere the
    installer presents elapsed time.

## r108 ports Git-sync architecture correction --- 2026-08-19

-   [x] **DESIGN CORRECTED AND IMPLEMENTED in r121 / live migration +
    repeated network sync regression PASSED 2026-08-22:**
    `https://codeberg.org/bmadonnaster/BFS-Linux.git` currently exposes
    only one branch, `main`. The BFSOS port collections are directories
    under that single branch rather than separate Git branches. Do not
    design `/etc/ports/*.git` around non-existent per-collection
    branches.
-   **Current repository layout assumption:** one Git repository / one
    `main` branch / multiple collection directories such as
    `ports/core`, `ports/opt`, `ports/xorg`, `ports/xfce`,
    `ports/plasma`, etc.
-   **Preferred maintenance direction:** Prefer retaining the
    single-branch multi-directory repository layout unless a
    stock-CRUX-compatible solution proves impractical. Separate branches
    per collection would significantly increase maintainer burden for
    cross-collection updates, auditing, dependency moves, and
    coordinated commits.
-   **Required design investigation:** Determine whether the CRUX Git
    ports driver can cleanly map one repository checkout to multiple
    collection subdirectories. If not, evaluate a small BFSOS
    extension/wrapper that performs one Git fetch/pull and exposes the
    corresponding `ports/<collection>` directories as the normal
    `/usr/ports/<collection>` trees while preserving `ports -u` as the
    user-facing command.
-   **Avoid duplicate clones:** Do not clone the same large repository
    once per collection merely to satisfy ten `/etc/ports/*.git` entries
    unless no cleaner approach exists.
-   **Target user experience:** `ports -u` remains the normal command.
    Internally, BFSOS should synchronize the single Codeberg repository
    efficiently and update all configured BFSOS collections without the
    current HttpUp per-file failure mode.
-   **Git/base policy remains:** Git still belongs in the BFSOS base
    package set and should be removed from the installer
    optional-package list once the Git-backed ports sync path is
    implemented and validated.
-   **HttpUp compatibility:** Keep HttpUp support available for
    third-party collections that still use it; migrate BFSOS-owned
    collections away from HttpUp-specific `REPO`, `.httpup-*`, and
    `httpup-repgen` maintenance once the Git path is proven.
-   **Decision deferred:** Do not restructure the Codeberg repository
    into separate branches yet. Revisit only if the stock driver
    limitations make the single-branch architecture unreasonably
    complex.
-   **Regression tests:** (1) fresh system with Git in base can run
    `ports -u`; (2) one repository update refreshes all BFSOS collection
    directories; (3) no collection is cloned redundantly; (4) a failed
    network sync leaves the previous ports tree intact; (5) third-party
    HttpUp collections still update normally.
-   **Live existing-system migration result --- PASSED 2026-08-22:** An
    installed BFSOS VM with the ten legacy `/etc/ports/*.httpup`
    definitions and Git 2.55.0 successfully migrated to the single BFSOS
    Git monorepo configuration. `ports -u` fetched the Codeberg
    repository and populated all configured collections; `pkgutils` and
    Git upgraded successfully, and after resolving the package-ownership
    edge case `prt-get` upgraded to 5.19.9-3 and `prt-get sysup`
    reported the system up to date.
-   **Migration ownership edge case discovered:** Manually
    pre-installing `/etc/ports/bfsos.git` before upgrading the `prt-get`
    package caused `pkgadd` to refuse the update because `prt-get` now
    owns that path. Migration/update logic must avoid creating an
    unowned `bfsos.git` before the owning package is installed/upgraded,
    or explicitly move/handle the legacy copy first.
-   **Git manifest false-positive discovered and FIX VERIFIED live:**
    Normal `pkgmk` builds create `.md5sum` and `.footprint` files inside
    port directories. The original Git-driver manifest hashed every
    file, so a subsequent `ports -u` incorrectly reported
    `Local modifications detected in /usr/ports/core` after ordinary
    package builds. Update `manifest_tree()` to exclude generated
    `.md5sum` and `.footprint` files while continuing to protect real
    source/Pkgfile/patch/script edits. With those generated files
    intentionally left in place, `ports -u` completed with no errors
    after the exclusion fix, confirming the regression fix.
-   **Repeated-sync regression --- PASSED:** After applying the manifest
    exclusion fix, repeated `ports -u` operation completed without
    local-modification errors. Keep this as a required regression test
    for RC1.

## r109 UI status-color consistency --- 2026-08-20

-   [x] **FIX VERIFIED LIVE in Bootstrap after Stage 2 (2026-08-22);
    installer consistency remains covered separately: make `[AVAILABLE]`
    visually distinct from `[COMPLETE]`.**
    -   Current bootstrap menu displays `[AVAILABLE]` in green, the
        same/similar success color used for `[COMPLETE]`, which makes an
        available-but-not-run action look completed at a glance.
    -   Change `[AVAILABLE]` to a **bright, high-visibility color that
        is not green**.
    -   Apply the same status-color rule consistently to **both
        `bootstrap.sh` and the BFSOS installer** anywhere `[AVAILABLE]`
        or an equivalent available/ready state is shown.
    -   Preserve green for `[COMPLETE]` / successful-completion states.
    -   Preserve red for `[PENDING]` where currently used.
    -   Verify readability with the installer/bootstrap dialog theme and
        selected-row highlighting.
    -   Audit both scripts for all status rendering paths so
        `[AVAILABLE]` cannot fall back to green in another menu or
        refresh state.
    -   **Live Bootstrap regression PASSED (2026-08-22):** menu showed
        `[COMPLETE]` in green, `[AVAILABLE]` in a distinct
        yellow/high-visibility color, `[PENDING]` in red, and `[EXIT]`
        distinctly after Bootstrap Stage 2 completed.

## r110 LUKS device-selection duplicate JBOD/MD device --- 2026-08-20

-   [x] **FIX IMPLEMENTED in installer r54 / runtime regression pending:
    LUKS block-device selector listed the same Linear/JBOD md device
    multiple times.**
    -   Reproduced during live installer testing after creating a
        Linear/JBOD array.
    -   In **Create LUKS container → Select the block device**,
        `/dev/md0 1.5T linear` is displayed repeatedly (six entries in
        the observed test) even though it is one block device.
    -   Expected: each eligible block device appears **exactly once**.
    -   Audit the device-discovery/aggregation code for duplicate
        enumeration of md/Linear/JBOD devices, including any loops over
        component disks, `lsblk`, `/proc/mdstat`, `mdadm`, or cached
        installer device lists.
    -   Deduplicate by canonical block-device path before building the
        dialog menu, while retaining the correct size/type/status
        metadata.
    -   Verify the fix for **Linear/JBOD and all supported md RAID
        levels**, since the underlying enumeration bug may not be
        Linear-specific.
    -   Regression test layered storage flows: md/Linear → LUKS, md/RAID
        → LUKS, and selection after returning/re-entering the LUKS menu.

## r111 Users & Groups review UI cleanup --- 2026-08-20

-   [x] **IMPLEMENTED in installer r54 / runtime regression pending:
    improve the Users & Groups review dialog layout.**
    -   Current review contains the needed information, but account
        details are presented as a dense text block and are harder to
        scan than necessary.
    -   Give the **Primary account** and **Additional accounts** clear
        visual sections/separators.
    -   Render every account with a consistent field layout,
        e.g. `User`, `Type`, `Groups`, `Password`, and `Login` where
        applicable.
    -   Wrap long group lists cleanly beneath the `Groups:` field
        instead of allowing the review to look like an unstructured
        paragraph.
    -   Keep wording concise while preserving important distinctions
        between Standard users and System/service accounts.
    -   Consider a compact right-side account status/type marker such as
        `[STANDARD]` / `[SYSTEM]` if it fits cleanly with the existing
        dialog theme.
    -   Verify layout at the installer's supported terminal sizes and
        with long usernames/group lists.
-   [x] **FIX IMPLEMENTED in installer r54 / runtime regression pending:
    remove stray encoding/control-character garbage from account
    review.**
    -   Live testing shows `~@~T`-style garbage between
        additional-account usernames and their account type (observed
        for `user2` and `sys`).
    -   Audit any Unicode punctuation/dash characters and text passed
        through shell/dialog formatting.
    -   Prefer safe plain-text/ASCII separators where appropriate so the
        review renders correctly under the Gentoo Live environment and
        BFSOS console locale.
    -   Verify Primary and Additional account rows render without
        mojibake/control-character artifacts.

## r112 Dialog theme persistence across new installer screens --- 2026-08-20

-   [x] **FIX IMPLEMENTED in installer r54 / runtime regression pending:
    newly added Dialog screens retain the currently selected installer
    theme.**
    -   Live testing of the new account/password dialogs shows they fall
        back to a different/default Dialog appearance instead of
        inheriting the theme previously selected in the installer.
    -   This applies to the new **System Settings**, **Users and
        Groups**, account/password, LVM-capacity, review, confirmation,
        and any other newly added dialogs introduced in recent installer
        revisions.
    -   Expected behavior: once the user selects an installer theme,
        every subsequent Dialog invocation in that installer session
        must use the same theme consistently until the user explicitly
        changes it.
    -   Audit helper functions and direct `dialog` invocations for
        missing `DIALOGRC`, environment propagation, `--colors`,
        backtitle/title options, or alternate execution paths that
        bypass the normal themed-dialog wrapper.
    -   Prefer routing all Dialog calls through the same shared
        helper/environment so new screens cannot silently fall back to
        the stock theme.
    -   Theme selection/state should also survive normal menu navigation
        and installer profile/resume behavior wherever theme persistence
        is already intended.
    -   Regression tests: choose each available theme, open the new
        password/account dialogs and all newly added System
        Settings/LVM/review screens, navigate Back/Cancel/re-enter
        paths, and confirm the selected theme remains visually
        consistent throughout.

## r113 account-name/group collision + failure-result logging --- 2026-08-20

-   [x] **FIX IMPLEMENTED in installer r54 / runtime regression pending:
    account creation must reject a username that collides with an
    existing group name.**
    -   Live test created a System/service account named `sys`.
    -   BFSOS already has an existing `sys` group, so `useradd` failed
        with:
        `group sys exists - if you want to add this user to that group, use -g.`
    -   Because System/service accounts default to a private primary
        group, a username whose same-named group already exists cannot
        satisfy that policy automatically.
    -   Validate proposed usernames against **both existing usernames
        and existing group names** before saving account configuration
        or entering the install transaction.
    -   For the default private-group policy, reject such collisions
        with a clear Dialog message explaining that the account name
        conflicts with an existing group and asking for another
        username.
    -   Do not silently reuse the pre-existing group unless the
        installer gains an explicit advanced option for that behavior.
    -   Apply the same validation to the primary Standard user and
        additional Standard users because `useradd -m -U`/private-group
        creation can hit the same collision.
    -   Regression tests: attempt usernames matching built-in groups
        such as `sys`, `bin`, `audio`, `wheel`, etc.; verify the
        installer blocks them before installation. Verify a
        non-conflicting Standard and System/service account both create
        successfully.
-   [x] **FIX IMPLEMENTED in installer r54 / runtime regression pending:
    installer session log footer must not report SUCCESS / exit 0 after
    a caught installation failure.**
    -   The live run displayed `Installation operation failed` with exit
        status `9`, and the chroot log shows `useradd` failed followed
        by `Installer exited.`
    -   Despite that, the installer log footer incorrectly recorded:
        `Result: SUCCESS` `Exit status: 0`
    -   Failure/session status propagation is still inconsistent on this
        path.
    -   Ensure any chroot/configuration/install-operation failure
        records the actual nonzero status in the final session result
        unless a later retry fully succeeds and explicitly clears the
        failure state.
    -   Keep the Dialog-reported failure status, internal session
        failure flag, shell exit status, and final log footer
        consistent.
    -   Regression test: intentionally trigger an account-creation
        failure, return to the menu, quit without retrying, and verify
        the final log says FAILURE with the original/nonzero status.
        Then retry successfully and verify a completed session may
        legitimately finish SUCCESS/0.

## r124 pkgmk tmpfs build-work cleanup bug --- 2026-08-22

-   [ ] **PRE-RC1 FIX REQUIRED: preserve the mounted
    `/var/cache/pkg/build-work` tmpfs mountpoint during package
    cleanup.**
    -   Live BFSOS VM testing repeatedly prints:
        `rm: cannot remove '/var/cache/pkg/build-work': Device or resource busy`
        during otherwise successful package builds/updates.
    -   Confirmed with `findmnt` that `/var/cache/pkg/build-work` is
        itself an active `tmpfs` mount
        (`rw,nosuid,nodev,...,size=16777216k,mode=775,uid=82,gid=82`).
    -   Root cause: a BFSOS/pkgmk cleanup path is attempting to remove
        the **mounted directory itself** (equivalent to
        `rm -rf /var/cache/pkg/build-work`) rather than only deleting
        the contents of the mounted workspace.
    -   Required behavior: when `build-work` is an active mountpoint,
        cleanup must remove files/directories *inside* the workspace
        while preserving the mountpoint. Do not unmount/recreate the
        tmpfs merely to perform routine per-package cleanup.
    -   Audit `pkgutils`/`pkgmk`, BFSOS wrappers, `bootstrap.sh`, and
        related cleanup helpers for `rm -rf` operations targeting
        `build-work` or the configured package work directory.
    -   Cleanup must include normal and hidden entries without
        attempting to remove `.`/`..`, and must remain safe if the
        workspace is not mounted or is already empty.
    -   Regression test: build/update several packages consecutively
        with the tmpfs workspace mounted; confirm package cleanup
        succeeds with **no `Device or resource busy` warning**, the
        tmpfs remains mounted, and no stale build contents leak into the
        next package build.
    -   This is currently noisy rather than build-blocking (observed
        package builds still succeeded), but it should be fixed before
        BFSOS 1.0-rc1.

## r125 base package policy --- rsync --- 2026-08-22

-   [ ] **PRE-RC1 BASE UPDATE: add `rsync` to the BFSOS Bootstrap/base
    package set.**
    -   Live installed-VM testing confirmed `rsync` was available in the
        ports tree but was not installed by default in the existing
        BFSOS base.
    -   `rsync` is considered sufficiently useful for normal system
        administration, recovery, migration, backup, diagnostics, and
        BFSOS maintenance workflows to be part of the base rather than
        an installer-only optional package.
    -   Add `rsync` to the Bootstrap/base package list before producing
        the next canonical base/rootfs archive.
    -   Do not add a redundant installer optional-package prompt once
        `rsync` is guaranteed by the base.
    -   Regression test: create a fresh base/rootfs archive and fresh
        install, then verify `command -v rsync` and `rsync --version`
        succeed without installing any optional packages.

## r126 pre-1.0 ISO delivery + text-browser installer options --- 2026-08-22

-   [ ] **PRE-1.0 RELEASE DELIVERY GOAL: provide a BFSOS
    installation/live ISO before BFSOS 1.0 final if practical.**
    -   Keep the current external-live-environment workflow usable
        during development, but add a first-party BFSOS ISO so users do
        not need to obtain and boot a separate Gentoo LiveGUI image
        merely to install BFSOS.
    -   The ISO should carry or provide straightforward access to the
        BFSOS installer, required installation/storage tools,
        networking, SSH, package/ports tooling needed for
        installation/recovery, and enough diagnostics to troubleshoot
        boot/storage failures.
    -   Prefer reusing the existing Bootstrap/installer logic rather
        than creating a second independent install implementation for
        ISO media.
    -   Preserve both graphical/local-console and serial-console
        troubleshooting paths where practical.
    -   Define how the ISO obtains the base rootfs used by the
        installer: embedded release archive, downloadable archive, or
        another deterministic release-artifact path. Avoid requiring a
        development checkout merely to perform a normal release install.
    -   ISO work should not destabilize the currently validated
        installer/storage stack immediately before RC1; stage it as
        release-packaging/delivery work around the RC cycle.
    -   Regression targets: BIOS and UEFI boot where supported,
        networking, SSH access, installer launch, storage tools, loading
        the release base archive, completing an install, and booting the
        installed BFSOS system.
-   [ ] **INSTALLER OPTIONAL PACKAGES: add `lynx` and `links` as
    optional text-mode web browsers.**
    -   Expose both independently in the installer optional-package
        selection; do not make either browser a required base dependency
        solely for ordinary BFSOS installation.
    -   Keep the package names and descriptions distinct so users can
        choose Lynx, Links, both, or neither.
    -   Include them in final optional-package review and normal
        dependency-aware installation via `prt-get`.
    -   Verify each selected browser installs and launches successfully
        on a fresh system after `ports -u`/package synchronization.

## r127 installer/base-archive source-cache retention option --- 2026-08-22

-   [ ] **INSTALLER SETTINGS / BUILD-ARTIFACT OPTION: optionally
    preserve downloaded source archives inside the generated BFSOS
    base/rootfs archive.**
    -   Add a persisted Installer Settings toggle such as **Keep package
        source archives in base archive**, default **off** for
        normal/release-size builds and optionally enabled for
        development/testing builds.
    -   When enabled, copy the already-downloaded package source
        tarballs/files into the installed system's normal pkgmk
        source-cache location before the base/rootfs archive is created.
    -   Use the same canonical source-cache path that installed
        BFSOS/pkgmk uses for future downloads (currently
        `/var/cache/pkg/sources` unless the package-cache policy
        changes), rather than inventing a second source directory.
    -   Preserve filenames and usable permissions/ownership so later
        `pkgmk`, `prt-get`, installer package operations, and regression
        builds can reuse the cached sources without downloading them
        again.
    -   Do not copy temporary build trees, extracted source directories,
        package work directories, or completed binary packages as part
        of this option; the intent is specifically to retain reusable
        source archives/distfiles.
    -   Avoid duplicating source files already present in the target
        cache and ensure the archive-creation step reports the
        additional source-cache size so large development archives are
        not created accidentally.
    -   Include the selected state in final review/logging so it is
        obvious whether a generated base archive is a compact
        release-style archive or a development/test archive containing
        source distfiles.
    -   Regression test: enable the option, create a fresh base/rootfs
        archive, inspect `/var/cache/pkg/sources` inside the archive,
        install from it, then build/update representative packages with
        networking disabled or source URLs unavailable and confirm
        cached sources are reused.
    -   Release policy: official compact release archives may keep this
        disabled by default; development/testing archives can enable it
        to reduce repeated downloads and speed installer/package
        regression cycles.

## r128 bootstrap/installer non-interactive CLI interface --- 2026-08-22

-   [ ] **PRE/POST-RC CLI USABILITY: every major Bootstrap and installer
    operation should be invokable without entering the Dialog/text
    menus.**
    -   Preserve the current interactive menu UX as the default when no
        command-line action is supplied.
    -   Add a complete command-line interface to both `bootstrap.sh` and
        the current BFSOS installer so users, developers, CI, test
        harnesses, and automation can invoke supported actions directly.
    -   Both programs must provide `--help` (and preferably `-h`)
        describing available actions, options, accepted values,
        defaults, examples, and exit-status behavior.
    -   Support stable named options/subcommands for major operations;
        numeric aliases may also be provided where useful for parity
        with menu numbering, but automation should not depend solely on
        menu presentation/order.
    -   Bootstrap CLI targets should cover the same meaningful actions
        exposed by the menu, including toolchain build/restore, base
        build stages, verification, archive creation/restoration,
        chroot, installer launch, cleanup/reset operations, and relevant
        build/settings overrides.
    -   Installer CLI targets should cover configuration and execution
        actions exposed by the installer, including storage/profile
        input, base archive selection, system settings, optional
        packages, bootloader settings, installation/retry, recovery
        where safe, chroot/inspection, logging/output controls, and
        future utility actions such as ISO creation.
    -   **ISO builder CLI requirement:** the future standalone BFSOS ISO
        creation script (for example `bfs-build-iso.sh`) must itself
        support `--help`/`-h` and non-interactive switches rather than
        being usable only through Installer Settings. At minimum expose
        explicit options for selecting the base/rootfs archive,
        kernel/initramfs/release inputs where applicable, output
        path/name, included installer/version, optional source-cache
        inclusion, and the build/start action.
    -   The Installer Settings -\> **Build BFSOS ISO** entry should act
        as a frontend to the same ISO-builder script/CLI, not maintain a
        second ISO-generation implementation. Interactive and
        command-line ISO creation must therefore share the same
        validation, defaults, artifact-generation logic, logging, and
        exit statuses.
    -   ISO CLI regression: verify `bfs-build-iso.sh --help`, build an
        ISO entirely from switches without entering a menu, reject
        missing/invalid required inputs cleanly, return meaningful
        nonzero status on failure, and confirm the Installer Settings
        frontend produces the same artifact path/content for equivalent
        settings.
    -   Configuration values supplied on the command line must pass
        through the same validation/helpers used by the interactive UI;
        do not maintain a second independent validation implementation
        that can drift from Dialog behavior.
    -   Allow useful non-interactive combinations such as
        `--action <name>` plus explicit `--option value` settings,
        profile/config-file input where appropriate, and a deliberate
        `--yes`/assume-confirmation mechanism only for operations that
        are safe to automate.
    -   Destructive storage actions must retain strong safeguards.
        Non-interactive mode must require explicit
        target/topology/confirmation data and must never infer
        permission to wipe or format disks merely because a CLI action
        was requested.
    -   Commands should return meaningful, documented nonzero exit
        statuses on validation, download, build, storage, install, or
        bootloader failures so scripts/CI can distinguish success from
        failure without scraping UI text.
    -   Provide machine-readable or plain-text output modes where
        practical so automated tests do not depend on Dialog escape
        sequences or screen rendering.
    -   Maintain backward compatibility with normal interactive
        invocation: running `./bootstrap.sh` or the installer with no
        action switches should continue to open the current menu
        interface.
    -   Regression matrix: compare interactive and CLI execution of
        representative non-destructive actions; run each Bootstrap stage
        directly by CLI; perform a fully specified disposable-VM
        installer run without menu navigation; verify `--help`; verify
        invalid options fail clearly; verify Ctrl-C/nonzero subprocess
        failures propagate correctly; verify destructive actions refuse
        to proceed when required explicit confirmation/targets are
        absent.

## r131 Bootstrap verification status contrast --- 2026-08-22

-   [ ] **UI COLOR FIX: make Bootstrap `[PASSED!]` verification status
    more visually distinct/high-contrast.**
    -   Live testing after successful Stages 1, 2, and optional Stage 3
        showed Stage 4 verification as `[PASSED!]` in orange/brown on
        the cyan Dialog background.
    -   The current orange/brown does not stand out sufficiently from
        the background or neighboring status colors.
    -   Change `[PASSED!]` to a high-contrast status color;
        **bright/bold white is the preferred candidate** with the
        current palette.
    -   Preserve the established status distinctions: `[COMPLETE]`
        green, `[AVAILABLE]` yellow/high-visibility, `[PENDING]` red,
        and `[EXIT]` separately distinguishable.
    -   Apply the change consistently anywhere Bootstrap renders a
        successful verification/pass state, including text-mode output
        where applicable.
    -   Regression test on the actual Bootstrap menu after Stage 4
        passes and confirm `[PASSED!]` is immediately distinguishable
        from COMPLETE, AVAILABLE, PENDING, and EXIT states and remains
        readable on selected/unselected rows.

## r132 Bootstrap installer auto-selection by newest timestamp --- 2026-08-22

-   [ ] **BOOTSTRAP INSTALLER DISCOVERY: stop relying on
    `scripts/install-bfs-menu-current.sh` symlink for normal installer
    launch.**
    -   When Bootstrap launches the BFSOS installer, discover the real
        versioned installer scripts matching the supported naming
        pattern (for example `scripts/install-bfs-menu-v50-*.sh`) and
        automatically select the newest usable file.
    -   Prefer the installer with the newest filesystem modification
        date/time. Use a deterministic secondary sort such as filename
        if timestamps are identical.
    -   Validate that the selected candidate is a regular readable shell
        script and passes a lightweight syntax check (`bash -n`) before
        launching it.
    -   Do not allow a stale, broken, or incorrectly pointed
        `install-bfs-menu-current.sh` symlink to cause Bootstrap to
        launch an older installer revision.
    -   The `install-bfs-menu-current.sh` symlink may remain as a
        developer convenience/backward-compatibility alias, but
        Bootstrap should not depend on it for installer selection.
    -   Show/log the exact installer path, filename, and modification
        timestamp selected so test logs make it obvious which revision
        actually ran.
    -   If the newest candidate fails validation, report that candidate
        clearly and either fall back to the next-newest valid installer
        with an explicit warning or refuse to launch; do not silently
        run an unexpected revision.
    -   Regression test: create multiple installer revisions with
        different modification times, point
        `install-bfs-menu-current.sh` at an older revision (and
        separately make it broken), then verify Bootstrap still selects
        and launches the newest valid real installer script.
    -   This refines the earlier tracker requirement that Bootstrap
        discover the newest versioned installer instead of hard-coding a
        filename; the selection rule is now explicitly **newest
        modification date/time**, independent of symlink state.

## r133 installer MD reset discovery + bootstrap newest-installer selection --- 2026-08-22

-   [x] **IMPLEMENTED in installer r60 --- deterministic active-MD
    metadata wipe discovery.**
    -   Runtime regression on the six-member Linear/JBOD test array
        proved installer r59 still displayed
        `No safe unmounted storage candidates were found` even though
        `/dev/md127` was active and `wipefs -n /dev/md127` showed two
        `crypto_LUKS` signatures.
    -   Confirmed environment: `/dev/md127` is visible under
        `/sys/class/block/md127/md`, the BFSOS project filesystem is
        `/dev/vdh1`, and the live environment is not backed by
        `/dev/md127`.
    -   r60 snapshots all active MD arrays and their member devices
        **before** upper storage layers are unwound.
    -   Active MD arrays are then added explicitly to the destructive
        checklist when they are safe/unmounted and expose wipeable
        array-level metadata. Discovery no longer depends on
        `lsblk TYPE`, `/proc/mdstat` field layout, or a
        post-deactivation rescan.
    -   Active MD member partitions are suppressed while the array
        remains assembled. Selecting `/dev/mdX` wipes only array-level
        LUKS/LVM/filesystem signatures and does **not** zero member MD
        superblocks.
    -   If an active MD array is detected but rejected by every
        safe-candidate check, the empty-state dialog now names the
        detected array(s), making future rejection failures diagnosable
        instead of silently reporting no candidates.
    -   **Runtime regression:** with `/dev/md127` Linear/JBOD active and
        carrying the old LUKS signature, Destroy selected metadata must
        show `/dev/md127` as `Active MD array; crypto_LUKS`, must not
        show `/dev/vdb1`-`/dev/vdg1`, and wiping `/dev/md127` must leave
        the Linear array assembled with a blank FSTYPE/signature scan.
-   [x] **IMPLEMENTED in Bootstrap r60 --- launch newest real installer
    by filesystem modification timestamp.**
    -   Replaces version-like filename sorting with actual
        modification-time sorting of real
        `scripts/install-bfs-menu-v*.sh` files.
    -   `scripts/install-bfs-menu-current.sh` is explicitly excluded
        from normal discovery; it may remain only as a
        convenience/backward-compatibility symlink.
    -   Each candidate is validated with `bash -n` before selection. A
        syntactically broken newest candidate is reported and skipped in
        favor of the next-newest valid installer rather than silently
        launching it.
    -   Bootstrap logs/displays the exact selected installer path and
        its modification timestamp before handoff.
    -   Deterministic tie-break uses pathname ordering after
        modification time.
    -   **Regression:** point `install-bfs-menu-current.sh` at an older
        file and separately break/remove the symlink; Bootstrap must
        still choose the newest valid real installer by mtime.

## r134 Bootstrap PASSED status color correction --- 2026-08-22

-   [x] **IMPLEMENTED in Bootstrap r61 --- Stage 4 `[PASSED!]` is now
    bright/bold white.**
    -   Runtime UI check after Bootstrap r60 confirmed `[PASSED!]` was
        still orange/yellow.
    -   Root cause: Dialog `_dialog_verification_status()` still emitted
        `\\Z3PASSED!`, where Dialog color 3 is yellow, and text-mode
        rendering still used `$COLOR_YELLOW`.
    -   Dialog mode now emits bold white (`\\Zb\\Z7PASSED!\\Zn`) for
        Stage 4 verification success.
    -   Text mode now renders `PASSED!` as ANSI bold white.
    -   Existing meanings remain unchanged: green = `COMPLETE`, yellow =
        `AVAILABLE`, red = `PENDING`/unavailable.
    -   **Runtime regression:** after Stage 4 has passed, verify
        `[PASSED!]` is clearly bright white on the Slackware cyan menu
        and remains distinct from green COMPLETE and yellow AVAILABLE.

## r135 Filesystem plan / Continue screen consolidation --- 2026-08-22

-   [ ] **INSTALLER UI: put the filesystem plan and Continue action on
    the same Dialog screen.**
    -   Current workflow separates reviewing the filesystem plan from
        the action used to continue the installation, creating an
        unnecessary extra screen/navigation step.
    -   Desired workflow: the filesystem-plan screen should display the
        complete configured filesystem/mount-point plan and provide the
        action to continue directly from that same screen.
    -   Keep Back/Edit behavior available so the user can return to
        filesystem assignments when something in the plan needs
        changing.
    -   Do not add another confirmation/menu screen merely to continue
        after the plan has already been reviewed.
    -   Preserve existing filesystem-plan validation and storage safety
        checks before allowing Continue.
    -   This complements the existing single multi-entry filesystem
        assignment workflow: assignment/editing remains the
        configuration step, while the resulting plan and Continue
        control are consolidated into one review screen.
    -   **Regression test:** configure the filesystem assignments,
        finish the assignment workflow, verify the complete filesystem
        plan is shown with Continue available on that same screen, and
        confirm proceeding does not require a second standalone Continue
        screen.

## r136 pkgutils/pkgmk.conf authoritative BFSOS defaults --- 2026-08-22

-   [x] **IMPLEMENTED in project consolidation r138 — PKGUTILS CONFIGURATION: make the packaged `/etc/pkgmk.conf`
    the authoritative permanent BFSOS default instead of relying on
    Bootstrap to repair it afterward.**
    -   Current `ports/core/pkgutils/pkgmk.conf` ships the three
        cache/work directory settings commented out even though the
        pkgutils Pkgfile installs that file directly as
        `$PKG/etc/pkgmk.conf`.

    -   Activate these permanent BFSOS defaults in
        `ports/core/pkgutils/pkgmk.conf`:

        ``` bash
        PKGMK_SOURCE_DIR="/var/cache/pkg/sources"
        PKGMK_PACKAGE_DIR="/var/cache/pkg/packages"
        PKGMK_WORK_DIR="/var/cache/pkg/build-work/pkgmk-$name"
        ```

    -   Update the pkgmk internal/script fallback patched by
        `ports/core/pkgutils/Pkgfile` to use the same per-package work
        path:

        ``` bash
        PKGMK_WORK_DIR="/var/cache/pkg/build-work/pkgmk-$name"
        ```

        rather than the shared `/var/cache/pkg/build-work` directory.

    -   Bump the `pkgutils` port release so installed BFSOS systems
        receive the corrected package/configuration behavior through a
        normal package update.

    -   Keep permanent final-system pkgmk policy owned by the pkgutils
        port. Bootstrap Stage 1/2/3 may continue generating temporary
        bootstrap-specific pkgmk configuration where required.

    -   Remove or reduce Bootstrap's final-system `PKGMK_WORK_DIR`
        rewrite/repair block to a validation check once pkgutils ships
        the authoritative setting, avoiding policy duplication across
        the port, pkgmk fallback, and Bootstrap.

    -   Preserve `/var/cache/pkg/build-work` as the parent tmpfs/mount
        point only; individual package builds must operate below it in
        `pkgmk-$name` work directories.

    -   This also addresses the observed failure
        `rm: cannot remove '/var/cache/pkg/build-work': Device or resource busy`:
        pkgmk must never treat the mounted parent work directory itself
        as the removable per-package build directory.

    -   Audit the installed `/etc/pkgmk.conf` after building/upgrading
        pkgutils and verify the source, package, and work directory
        settings are active rather than commented.

    -   **Regression test:** build at least two different ports and
        verify their work paths resolve below
        `/var/cache/pkg/build-work/pkgmk-<package-name>`, cleanup
        removes only the package-specific directory, the parent tmpfs
        remains mounted, and no `Device or resource busy` error occurs.

## r137 confirmed LUKS + serial-console ordering fix --- 2026-08-22

-   [x] **IMPLEMENTED in installer r61 / runtime regression still recommended — RUNTIME ROOT CAUSE CONFIRMED:**
    when both the QEMU/libvirt serial console and graphical console are
    enabled, generate the kernel console arguments in this order:
    `console=ttyS0,115200 console=tty0`.
    -   The previous installer ordering,
        `console=tty0 console=ttyS0,115200`, reproducibly caused Dracut
        111 to reach `luksOpen` but fail to present a usable interactive
        LUKS password prompt, making early boot appear frozen.
    -   Removing the serial-console argument immediately restored the
        LUKS password prompts and allowed the installed MD Linear/JBOD
        -\> LUKS -\> LVM -\> Btrfs system to boot normally.
    -   Re-enabling serial support with the order reversed to
        `console=ttyS0,115200 console=tty0` also restored the LUKS
        prompts and booted successfully, confirming console ordering as
        the trigger.
    -   Update the installer serial-console generation logic and
        `/etc/default/grub` handling so `tty0` is always last whenever
        both consoles are requested.
    -   Preserve topology-derived `rd.luks.uuid=`, `rd.md.uuid=`,
        `rd.lvm.lv=`, root, and rootflags arguments and keep
        regeneration idempotent/deduplicated.
    -   Undo/avoid carrying the experimental Dracut
        `70crypt-lib/crypt-lib.sh` console-redirection patch as a
        permanent BFSOS fix; stock Dracut works when the console
        ordering is correct.
    -   **Regression test:** encrypted install with graphical console
        only; serial console only where applicable; graphical + serial
        with the corrected ordering; confirm LUKS prompts are usable and
        serial boot diagnostics remain available.


## r138 full-project consolidation, core static audit, and Linux 6.18 LTS refresh — 2026-08-22

- [x] **FULL PROJECT TREE CONSOLIDATED:** Bootstrap, installer, pkgutils defaults, core ports, documentation, and kernel flavors were updated together rather than handed off as isolated scripts.
- [x] **BOOTSTRAP:** retained r60 newest-installer-by-mtime discovery and syntax validation; Stage-4 `[PASSED!]` is bold white; bootstrap revision header advanced to r62.
- [x] **INSTALLER r61:** corrected dual-console ordering to `console=ttyS0,115200 console=tty0`, preserving `tty0` as the final console so Dracut/LUKS prompts remain interactive; updated LTS selector wording.
- [x] **PKGUTILS r14:** packaged `pkgmk.conf` now owns the BFSOS cache/work defaults and uses per-package `PKGMK_WORK_DIR=/var/cache/pkg/build-work/pkgmk-$name`; pkgmk fallback matches.
- [x] **LINUX 6.18 LTS:** `linux-lts` advanced from 6.12.101 to upstream longterm 6.18.45. The obsolete 6.12-only MD diagnostic patch and GCC compatibility patch were removed from the active source list/tree. The known-good BFSOS current-kernel config is used as the baseline and reconciled with `olddefconfig`.
- [~] **CORE PORTS AUDIT:** all 198 real core Pkgfiles were re-scanned for Bash syntax and required metadata; no syntax or required-metadata failures were found. The existing 78-package MLFS-development mapping remains version-aligned. A new report `docs/BFSOS-core-audit-r138-20260822.md` records every core port and outstanding dependency/runtime concerns.
- [x] **NUMPY DEPENDENCY METADATA:** removed the stale duplicate `meson-python` alias from the `python3-numpy` dependency comment; the actual BFSOS port is `python3-meson_python`.
- [ ] **RUNTIME REGRESSION REQUIRED BEFORE RC1 SIGN-OFF:** build/install `linux-lts` 6.18.45, verify its module/source/initramfs/GRUB coexistence with the normal kernel, exercise LUKS boot with graphical+serial consoles, build at least two ports through pkgutils r14, and run clean Bootstrap stages 1/2/3/4 plus fresh installer/boot tests.
- [ ] **FULL UPSTREAM VERSION AUDIT REMAINS ITERATIVE:** static checks cover every core port, while authoritative upstream/security version review for BFSOS-only packages remains a maintenance task and must not be represented as runtime-validated without actual builds/tests.

## r139 dual-kernel source-symlink policy — 2026-08-22

- [ ] **PRE-1.0 KERNEL SOURCE SYMLINK POLICY: make `/usr/src/linux` follow the selected/default BFSOS kernel flavor without breaking normal + LTS coexistence.**
  - Preserve fully versioned source trees for both flavors:
    - normal kernel: `/usr/src/linux-<kernelrelease>`
    - LTS kernel: `/usr/src/linux-<kernelrelease>-BFS-LTS` as produced by the package
  - Preserve a flavor-specific LTS convenience link:
    - `/usr/src/linux-lts -> linux-<current-LTS-kernelrelease>`
  - Treat `/usr/src/linux` as the conventional **system-default kernel source** link:
    - if only `linux` is installed, point `/usr/src/linux` to the normal kernel source tree;
    - if only `linux-lts` is installed, point `/usr/src/linux` to the LTS source tree;
    - if both are installed, preserve which flavor is configured as the system/default kernel instead of deciding by install order.
  - Use `prt-get isinst linux` and `prt-get isinst linux-lts` to resolve the single-kernel cases automatically.
  - For the dual-kernel case, store the selected/default flavor persistently, e.g. `/etc/bfsos/kernel-flavor` containing `linux` or `linux-lts`.
  - The installer must initialize the selected/default flavor according to the kernel chosen during installation.
  - Kernel package post-install/update logic must refresh its own flavor link and update `/usr/src/linux` **only when that flavor is the configured default**.
  - An LTS update must not steal `/usr/src/linux` from a normal-kernel default; a normal-kernel update must not steal it from an LTS default.
  - Keep `/boot` policy unchanged: use only versioned kernel/initramfs files and explicit GRUB entries; do not reintroduce generic `/boot/vmlinuz-*` or generic initramfs symlinks.
  - Regression matrix before 1.0:
    - normal kernel only;
    - LTS kernel only;
    - both installed with normal selected/default;
    - both installed with LTS selected/default;
    - update normal while LTS is default;
    - update LTS while normal is default;
    - verify `/usr/src/linux`, `/usr/src/linux-lts`, `/lib/modules/<kver>/{build,source}`, and GRUB entries after each case.

## r140 Wi-Fi regulatory database integration — 2026-08-22

- [ ] **PRE-1.0 WI-FI PACKAGING: add `wireless-regdb` and integrate it with `wpa_supplicant`.**
  - Current BFSOS tree has no `wireless-regdb`/regulatory database port or existing `regulatory.db` integration.
  - Create and validate a `wireless-regdb` port using the current upstream wireless regulatory database.
  - Install the kernel-consumed regulatory database files in the BFSOS firmware path, including:
    - `/usr/lib/firmware/regulatory.db`
    - `/usr/lib/firmware/regulatory.db.p7s`
  - Do **not** add obsolete CRDA-era userspace handling.
  - Make `wireless-regdb` a dependency of `wpa_supplicant` so normal `prt-get depinst wpa_supplicant` automatically installs the regulatory database.
  - Keep the installer free of unnecessary special-case package logic where possible: selecting `wpa_supplicant`/Wi-Fi support should obtain `wireless-regdb` through normal dependency resolution.
  - Verify the installer Wi-Fi option still installs the complete dependency chain.
  - Validate on boot that the kernel no longer reports:
    - `Direct firmware load for regulatory.db failed with error -2`
  - Validate regulatory-domain operation on real Wi-Fi hardware before 1.0 when practical.
  - This warning was discovered during the successful Linux `6.18.45-BFS-LTS` runtime test; it is a packaging/completeness issue and does not invalidate the LTS kernel boot test.

## r141 NetworkManager / Qt / Firefox packaging policy — 2026-08-22

- [ ] **PRE-1.0 NETWORKMANAGER DEPENDENCY AUDIT: keep the installer/networking stack lean and avoid dragging GUI desktop stacks into minimal installs.**
  - Audit the `NetworkManager` port and its full dependency chain.
  - Verify it does **not** depend on Qt, GTK, Xorg, Wayland GUI components, desktop-environment libraries, applets, or other graphical frontend packages unless those dependencies are strictly required by the core daemon/CLI functionality.
  - Prefer building the core NetworkManager daemon plus CLI/TUI functionality needed by BFSOS installation and normal headless/server use.
  - Keep graphical NetworkManager frontends/applets as separate optional packages rather than dependencies of the core `NetworkManager` package.
  - Confirm selecting NetworkManager in the BFSOS installer does not unexpectedly install a large portion of Xorg, Qt, GTK, GNOME, KDE/Plasma, or other desktop stacks.
  - Audit optional build flags and Meson options so desktop integrations are disabled when they are not required by the base networking package.
  - Record and justify any unavoidable graphical dependency before 1.0.
  - Regression test a fresh minimal install with NetworkManager selected and inspect the resulting dependency/package set.

- [ ] **PRE-1.0 QT5 REHABILITATION: restore a functional monolithic `qt5` port for legacy application compatibility.**
  - Keep Qt5 available in BFSOS for applications that still require it.
  - Audit the existing `qt5` port against current upstream/community maintenance practices and identify why the current BFSOS port is broken.
  - Apply the patches required for modern compilers, current glibc/binutils, OpenSSL, Python/tooling, and other contemporary build-environment changes as needed.
  - Prefer **one `qt5` port that builds the complete BFSOS-supported Qt5 stack** rather than maintaining a large collection of separately versioned Qt5 module ports.
  - Keep optional components/features disabled only where they are obsolete, insecure, unmaintained, or introduce clearly unnecessary dependencies.
  - Ensure the resulting package is internally version-coherent and suitable as a compatibility runtime/build dependency for remaining Qt5 applications.
  - Audit old patch files and source-tree workarounds; remove obsolete fixes and refresh still-required patches against the selected Qt5 release.
  - Verify the build completes with the BFSOS toolchain and representative Qt5 applications can compile/link/run against it.
  - Document any Qt5 modules intentionally excluded from the monolithic package.

- [ ] **PRE-1.0 QT6 PACKAGING POLICY: keep Qt6 as one coordinated monolithic BFSOS port.**
  - Prefer **one `qt6` port that builds the complete BFSOS-supported Qt6 stack** rather than splitting Qt6 into many separately maintained module packages.
  - Keep all Qt6 components built from a coherent upstream release/version set.
  - Audit dependencies and build options so optional desktop/media/database/web-engine features do not pull in unnecessary stacks unless explicitly supported by BFSOS.
  - Keep package ownership, include paths, CMake metadata, pkg-config data, plugins, translations, and runtime resources internally consistent.
  - Validate representative Qt6 applications against the resulting package.
  - If a component is intentionally excluded because it is too large, unsupported, or has an unsuitable dependency/security profile, document that exception rather than silently fragmenting Qt6 into many ports.

- [ ] **PRE-1.0 FIREFOX RELEASE POLICY: track normal rapid-release Firefox, not Firefox ESR.**
  - BFSOS should package the current normal/release-channel Firefox rather than following BLFS/LFS ESR version choices.
  - Use BLFS/LFS Firefox instructions as a build/reference source where helpful, but substitute the current stable non-ESR Firefox release and adjust patches/build flags accordingly.
  - Do not automatically downgrade or switch BFSOS to ESR merely because the current BLFS book uses ESR.
  - Audit Mozilla build dependencies and patches against the actual rapid-release Firefox version carried by BFSOS.
  - Keep the Firefox port updated on the normal stable release cadence, subject to BFSOS build/regression validation.
  - Validate startup, profile creation, TLS/CA handling, audio/video playback, hardware acceleration where supported, and representative web browsing before release.
  - Document any temporary version pin if a rapid-release Firefox update is blocked by a known BFSOS toolchain or dependency regression.

## r143 opt + Xorg deep audit / modernization pass — 2026-08-22

- [x] **STATIC SWEEP COMPLETE:** audited all 558 current `ports/opt` + `ports/xorg` Pkgfiles; all pass `bash -n`, required package dependency names resolve with **0 unresolved required dependencies**, and `git diff --check` passes.
- [x] **XORG DRIVER POLICY / META PACKAGE:** use current CRUX + upstream X.Org as the primary standalone-driver reference where BLFS no longer carries a complete driver set. Removed stray duplicate Nouveau directory `ports/xorg/brian@192.168.68.66`; restored `xf86-video-openchrome`; `xorg-driver` now covers all 23 present input/video driver ports with no missing/stale driver entry.
- [~] **XORG MODERNIZATION APPLIED / BUILD REGRESSION PENDING:** key Xorg infrastructure refreshed (Xorg Server 21.1.24, Xwayland 24.1.13, xorgproto 2025.1, xkeyboard-config 2.48, Mesa 26.1.7, plus selected current utilities/input drivers). Full Xorg and driver build/hardware validation remains required before 1.0.
- [~] **LLVM MONOREPO CLEANUP APPLIED / BUILD REGRESSION PENDING:** LLVM 22.1.8 now uses one `llvm-project` source/build for LLVM + Clang + compiler-rt. Removed the old split archive extraction/rename workflow.
- [~] **MESA CLEANUP APPLIED / BUILD REGRESSION PENDING:** Mesa 26.1.7 uses current Meson driver auto-selection rather than the old ad-hoc driver-string construction. Validate Gallium/Vulkan/X11/Wayland behavior after LLVM/Rust rebuilds.
- [~] **NETWORKMANAGER LEAN-CORE POLICY IMPLEMENTED / INSTALL REGRESSION PENDING:** NetworkManager 1.58.0 core package has no required Qt/GTK/Xorg dependency; keeps daemon/CLI/nmtui and disables unnecessary Qt, PPP, modem-manager, cloud-setup and CLAT integration in the core build. Verify a minimal installer selection does not drag in desktop stacks.
- [~] **QT5 COMPATIBILITY PORT REWORKED / BUILD REGRESSION REQUIRED:** `qt5-alternate` is renamed to `qt5`, remains a single BFSOS package under `/opt/qt5`, tracks Qt 5.15.19, and stages current Debian compatibility fixes for OpenSSL 4/current compiler/glibc/Python/Ninja-era build issues. Keep Qt5 for legacy applications until real build/application testing passes.
- [~] **QT6 MONOLITHIC POLICY IMPLEMENTED / BUILD REGRESSION REQUIRED:** Qt6 6.11.2 remains one coherent package under `/opt/qt6`; standalone BFSOS `qtwebengine` port is retired and QtWebEngine is built as part of the Qt6 source tree. Validate full WebEngine and representative application runtime before 1.0.
- [~] **RUST `/opt` POLICY PRESERVED / BUILD REGRESSION PENDING:** Rust 1.97.1 installs under `/opt/rustc-<version>` with `/opt/rustc` convenience link. Multilib bootstrap configuration was corrected to avoid duplicate TOML `[build]` tables.
- [~] **FIREFOX RAPID-RELEASE POLICY IMPLEMENTED / BUILD REGRESSION REQUIRED:** BFSOS Firefox tracks normal stable Firefox rather than ESR; port advanced to Firefox 154.0 and stale old-version source surgery was removed. Build/launch/TLS/media/profile validation remains required.
- [~] **WIRELESS REGDB IMPLEMENTED / WIFI RUNTIME PENDING:** new `wireless-regdb` port installs `regulatory.db` + `regulatory.db.p7s`; `wpa_supplicant` depends on it so installer/manual dependency installs pull it automatically. Verify kernel regulatory warning disappears on Wi-Fi hardware.
- [~] **LYNX + LINKS INSTALLER INTEGRATION IMPLEMENTED / RUNTIME PENDING:** installer r62 exposes Lynx and Links independently, persists both selections, shows them in text/Dialog paths, and installs them through normal `prt-get` dependency handling. Final audit also fixed the text-mode menu numbering collision so Lynx=5, Links=6, and Done=7.
- [~] **SOURCE/EXTRACTION CLEANUP:** hidden build-time downloads were removed from shared-mime-info and Speex; TeX Live source assets are declared through pkgmk sources; definite package build writes to host `/usr` were corrected in cdrdao, desktop-file-utils, FFmpeg and Subversion. Remaining complex-source ports require build validation rather than speculative mass rewriting.
- [ ] **PRE-1.0 COMPLETION CRITERION:** build/install the high-risk stack in dependency order (LLVM -> Rust -> Mesa -> Qt5/Qt6 -> Firefox, plus NetworkManager/wireless-regdb and Xorg server/drivers), then run fresh installer/boot regressions. Static audit completion alone does not close runtime validation.
- **Audit report:** `docs/BFSOS-opt-xorg-audit-r143-20260822.md` contains the full 558-port inventory and static audit results.

