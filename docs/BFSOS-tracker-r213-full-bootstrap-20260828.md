# BFSOS r213 — Full Bootstrap workflow

Source implementation adds a single Bootstrap action that runs Stages 1, 2, 3, 4, and 5 in order. It stops on the first failure, suppresses successful intermediate acknowledgement dialogs, and after a verified/compressed base is produced offers **Launch installer** or **Done**. Manual stage behavior remains unchanged and Stage 3 remains optional outside the full workflow.

Static release guards check the workflow structure. A real clean end-to-end Bootstrap remains the required runtime regression before this item is closed.

Bootstrap Settings also now exposes **Integrity verification** as its own category, while retaining secure defaults for MD5/checksum, signature, and footprint verification.
