r456: replace ISO cache write probe dependent on /usr/bin/runuser in base.
Apply to main BFSOS checkout before push. Includes ISO script, r455 regression update,
and new r456 test. After pushing, update iso-test via git pull --ff-only.
Does not modify installer implementation from r455.
