# Importing Davai tasks into Mitraillette: proposal

Goal: turn the tasks of a Davai experiment into Mitraillette test cases (pjob + namelist + input
data), and repeat this regularly, so that the Davai configurations can be run with `mitpack`
from any pack, without Vortex.

Pipeline:

1. **Capture**: run Davai once, from any pack, with `davpack-dumper` as the mpiauto
   `prefix-mpirun` (`mpiauto.DUMPER.conf`). Each MPI task is saved in `ro/`, `rw/` and `ref/`, with
   a `run.sh` and a `task.json`.
2. **Import** (new script, `bin/davimport`): select the saved tasks, remove what is not data,
   factor out common files, and store the data under `$INPUTFILES_HOME/davai/<experiment>`
   (`/scratch/work/marguina/mitraillette-data/davai/dv-0408-belenos@marguina`).
3. **Generate**: write `protojobs/DV_*.pjob`, `namelist/<cycle>/DV_*`, the PRO_FILE entries and
   the profiles they need.
4. **Validate**: run the new test cases with `mitpack`, using the pack Davai ran with, and compare
   their norms with the `ref/NODE.*` that Davai produced.
5. **Refresh**: repeat 1-4 for each new Davai version; namelist changes show up as git diffs. Old
   experiments stay on disk until the maintainer removes them.

Each proposal says what it impacts: **dumper** (`davpack-dumper`), **importer** (new script),
**data** (`mitraillette-data`), **pjobs**, **namelists**, **code** (`lib/mitraille`), **stations**.

---

## What dv-0408 contains

These are measured on `/scratch/work/marguina/dv-0408-belenos@marguina` (65 saved tasks):

| | |
|---|---|
| `ro/` files | 17182 files, 221 GB as seen, but 8682 distinct inodes, 62.6 GB on disk |
| `ro/` distinct (name, size) | 652, 50.3 GB: identical files are often *not* hard links of each other |
| `rw/` | 15.2 GB, mostly ODB databases (screening, minim, canari) and two 5.5 GB LFI `.d` files (canari alaro1) |
| `ref/` | 0.8 GB (`NODE.*`, `stdeo.*`, `drhook.prof.*`) |
| binaries | `AROME.X` 16 (including c923), `OOVAR.X oops.json` 13, `ARPEGE.X` 9, `IFS.X` 8, `ALARO.X` 7, `HARMONIEAROME.X` 2, `OOTESTVAR.X -t <test> oops.json` 10 |
| MPI layouts (nodes x tasks x threads) | 1x16x8 (24), 1x32x4 (22), 1x1x1 (12), 1x8x4 (2), 3x32x4 (2), 1x16x1, 1x4x1, 4x32x4 |
| largest inputs | `analyse.fa` 5.9 GB, `ref.ICMSHFCST+0006:00` 3.5 GB, `wavelet_224.cv` 3.2 GB, `ICMSHFCSTINIT` 2.1 GB, the binaries (1.1 GB each) |

Other observations:

- `fort.4` is complete: Vortex has already merged the namelist deltas, and set `NPROC=128`,
  `NSTRIN`, `NSTROUT`, `MBX_SIZE` and `NCOMBFLEN` (no `NPRGPNS` etc.).
- Besides `fort.4`, `rw/` contains other text inputs: `EXSEG1.nam`, `FPinline_6h.nam`,
  `spnorms.nam`, `xxt*`, `xxt.def`, `oops.json`, `namelist_oops`, `naml_geometry`,
  `bmatrix.nam`, `observations_ccma.nam`, `namchannels_*`.
- Some namelists hold absolute paths (`CRTABLEDIR='/home/rd/rdx/data/ifs/'` in the IFS forecast).
- `ro/` holds things that are not input data: the binaries, the `lfi_*` tools (64 symlinks each),
  `core -> /dev/null`, and `vortex-stamp-*` / `linux_bind.txt` files.
- Several tasks are the same configuration at several dates (5 analysis dates x 2 jobs for
  `arome/3dvar3h`, 4 dates of screening + minim for `arome/3dvar3hcnt0`).
- The Davai task path alone is not unique: `arome/3dvar3h/.../analysis.2025030912` is run by two
  jobs (`arome_BA3DVar_OOPS` and `arome_BA3DEnVar_OOPS`, the latter with 8 more ensemble members
  in `ro/`), and `arpege/4dvar6h/.../minim` and `screening` by `arpege_BSM4DVar_CNT0` and
  `arpege_BSHM4DVar_OOPS`.
- Environment in `run.sh`, identical in the 65 tasks:
  - `ECCODES_DEFINITION_PATH="$PWD":<ecCodes>/share/eccodes/definitions` (64 tasks; one without
    `"$PWD":`), `ECCODES_SAMPLES_PATH=<ecCodes>/share/eccodes/ifs_samples/grib1_mlgrib2`, with
    `<ecCodes>` = `/home/gmap/mrpe/mary/public/ecCodes/2.48.0/intel2023.2.0`;
  - `BUFR_TABLES=/opt/softs/libraries/emos/tables/bufr405/000405/`;
  - `LD_LIBRARY_PATH=<intel mpi>/libfabric/lib`.
- The binaries of this pack (`MASTERODB`, `OOVAR`, `OOTESTVAR`, `BATOR`) have
  `<ecCodes>/lib64` in their RPATH: the same ecCodes as in Davai's `ECCODES_*` variables. `libbufr`
  comes from the RPATH too (`khatib/opt/intel/2023.2/legacy/auxlibs-4.1`), but the BUFR tables do
  not (emos).
- The dumper does not record the exit code of the task (only `rc = N` on stderr), nor the Davai
  name of the task other than in the directory name.

---

## A. Capture (`davpack-dumper`)

### A1. Write a `task.json` next to `run.sh` — dumper
`run.sh` is meant for a human; the importer would have to parse it back. Proposal: the dumper also
writes `task.json` with what it already knows:

```json
{
  "experiment": "dv-0408-belenos@marguina",
  "task":    "gmkpack/arpege.intel23dp5.x/global798c22.intel23dp5.x/forecast.intel23dp5.x",
  "jobname": "canonical_arpege_global798c22",
  "jobid":   46105020,
  "pack":    "/home/gmap/mrpm/marguina/pack/_upon50t2_develop29OctROCMNVHPC.00.INTEL23DP5.x",
  "binary":  "ARPEGE.X", "args": [],
  "layout":  {"nn": 1, "nnp": 32, "openmp": 4},
  "sbatch":  ["--time=01:00:00", "..."],
  "env":     {"DR_HOOK_OPT": "prof", "...": "..."},
  "olddir":  "/path/of/the/task/directory",
  "rc":      0,
  "elapsed": 312
}
```

- `rc` and `elapsed` are written after the run. `rc` lets the importer skip failed tasks, and
  `elapsed` gives the `TIME` of the pjob.
- `olddir` lets the importer fix the absolute paths that remain.
- `pack` is the pack Davai ran from, for D1. `davpack` would add `--pack` to
  `mpiauto.DUMPER.conf`; today it does not, so `run.sh` also starts using `$PACK/bin`.
- `LD_LIBRARY_PATH` is added to the variables that the dumper skips, in `run.sh` as well as in
  `task.json` (B4).

### A2. Any pack — process
Imports can come from any pack. What the import keeps (namelists, input data) comes from Davai,
not from the pack; the pack only matters for D1, which must use the same binaries (recorded in
`task.json`). A pack with local changes is fine as long as its Davai run passes; failed tasks are
not imported (B1).

---

## B. Import (`bin/davimport`)

A Perl script in the mitraillette repository, sharing `lib/mitraille/util.pm`:

```
davimport --xp /scratch/work/marguina/dv-0408-belenos@marguina --version CY50T1
          [--select REGEX] [--exclude REGEX] [--keep] [--tag TAG] [--dryrun] [--data-dir DIR]
```

- `--version` chooses the namelist directory and the PRO_FILE (`namelist/cy50t1`,
  `PRO_FILE.CY50T1`). Without it, it is guessed from the pack in `task.json`, as `mitpack` does
  (50t2 → CY50T1), and the report says which one was chosen. It can also be set in
  `.mitpack.conf`.
- `--select` and `--exclude` are Perl regexes on the test case names (B1).
- `--keep` keeps the blocks of the previous experiments in the PRO_FILE (C4).
- The import id is the name of the Davai experiment (`dv-0408-belenos@marguina`). Its tag, used in
  the test case names (B1), is the experiment number (`0408`); `--tag` sets another one.

It ends with a report: test cases added, changed or removed in the PRO_FILE of the version, and the
data added to the pool (number of files and GB).

### B1. Selection and names — importer
- Skip tasks with `rc != 0` (A1).
- All dates are imported, each one as a test case.
- Name: `DV_` + experiment tag + Davai job name + task name, in upper case, with `-`, `.` and `/`
  replaced by `_`.
  The `standalone_` and `canonical_` prefixes of job names are dropped, and so is the compilation
  flavour of task names (`.intel23dp5.x`). A date suffix stays (`analysis.2025030912` →
  `ANALYSIS_2025030912`).

On dv-0408 this gives 65 distinct names, from 20 to 48 characters (the longest name in today's
PRO_FILEs has 60), e.g.:

| Davai job / task | Test case |
|---|---|
| `canonical_arpege_global798c22` / `forecast.intel23dp5.x` | `DV_0408_ARPEGE_GLOBAL798C22_FORECAST` |
| `standalone_ifs_global21` / `forecast.intel23dp5.x` | `DV_0408_IFS_GLOBAL21_FORECAST` |
| `armcu` / `arome_nominal` | `DV_0408_ARMCU_AROME_NOMINAL` |
| `arome_BA3DEnVar_OOPS` / `analysis.2025030912` | `DV_0408_AROME_BA3DENVAR_OOPS_ANALYSIS_2025030912` |
| `arome_BA3DVar_OOPS` / `analysis.2025030912` | `DV_0408_AROME_BA3DVAR_OOPS_ANALYSIS_2025030912` |
| `arpege_BSM4DVar_CNT0` / `minim` | `DV_0408_ARPEGE_BSM4DVAR_CNT0_MINIM` |
| `arpege_BSHM4DVar_OOPS` / `test_adjoint` | `DV_0408_ARPEGE_BSHM4DVAR_OOPS_TEST_ADJOINT` |
| `Bmat_arpege` / `read_ensemble-mpi4` | `DV_0408_BMAT_ARPEGE_READ_ENSEMBLE_MPI4` |
| `Physiography_arome` / `c923n1-nlcc2500` | `DV_0408_PHYSIOGRAPHY_AROME_C923N1_NLCC2500` |
| `LBC` / `from_arpege` | `DV_0408_LBC_FROM_ARPEGE` |

The importer stops if two tasks get the same name. The task path alone would not work: it gives 7
collisions on dv-0408 (see "What dv-0408 contains").

Since the tag is in the name, each import creates new test cases, with their own pjob, namelists and
data, and never changes those of another experiment. Davai numbers experiments per user
(`dv-0058-belenos@audouino` and a `dv-0058` of another user can both exist): the importer stops if
the tag is already used by another experiment in `$INPUTFILES_HOME/davai`, and `--tag` then
chooses another one (e.g. `--tag 0058A`).

### B2. Remove what is not data — importer
- Binaries: the executable that `run.sh` launches (and any `*.X`). The test case uses the binary of
  the pack (`$BINDIR/MASTERODB`, `OOVAR`, `OOTESTVAR`), with the mapping already in the dumper
  (`%davai2pack`).
- `lfi_*` tools, `core`, `linux_bind.txt`, `vortex-stamp-*`, `dirlst`.
- Symlinks: keep relative ones (`IOASSIGN -> CCMA.IOASSIGN`), replace absolute ones by the file.
- Absolute paths in text files (`olddir`, and `/home/...` paths of Vortex): reported. Those that
  point into the task directory are made relative (as `fixLFI` does), and the others are listed for
  a manual decision. `CRTABLEDIR` will only work on Belenos.

Possible follow-up (B2b): find the inputs that are never read. A validation run (D1) under
`strace -f -e trace=openat,open,stat` (on one rank) gives the list of files opened. `ref.*` (3.5 +
0.6 + 0.5 GB) are probably used by Davai's expertise only, not by the binary. It is not needed for a
first version.

### B3. Factor out common data: a content pool — importer + data
Layout under `$INPUTFILES_HOME/davai`:

```
davai/
  pool/<name>/<hash12>            one copy of each distinct file (or LFI F + F.d, as a unit)
  pool/INDEX                      size, sha1, path of each pool entry
  dv-0408-belenos@marguina/
    DV_0408_ARPEGE_GLOBAL798C22_FORECAST/
      ro/ICMSHFCSTINIT -> ../../../pool/ICMSHFCSTINIT/3f2a9c0e41b7
      rw/IOASSIGN      -> ../../../pool/IOASSIGN/91be03d2a7c4
      ref/NODE.001_01                (Davai's listings, for D1)
      task.json                      (from the dumper, minus env)
    DV_.../
  dv-0512-belenos@marguina/
    ...
```

- `ro/` and `rw/` both hold **relative symlinks** to the pool; the difference is only how the job
  installs them (C2): linked for `ro/`, copied for `rw/`. ODB databases are directories, so they go
  to the pool file by file, and each test case keeps its own tree of symlinks.
- The pool is browsable by file name (`pool/Const.Clim.sfx/` shows the two versions that dv-0408
  uses), unlike a pure hash store.
- Deduplication is cheap: group by inode, then by size, and hash only files that share a size with
  another file or with a pool entry (`pool/INDEX` means later imports only hash new files).
- Relative symlinks survive `ftpsync` (it writes `make_symlinks.sh`), so `hendrix-sync.sh` works
  unchanged when the Davai data goes to hendrix (D3).
- Expected size: under 50 GB for dv-0408 (62.6 GB distinct inodes, 50.3 GB distinct
  (name, size)), plus the `rw/` part, versus 57 GB for the whole of `mitraillette-data` today.
  Removing the binaries saves about 5 GB. The other dates of a task mostly add observations and
  backgrounds; the constants are shared. A later experiment should add only what changed.

### B4. Environment — importer + stations + code + pjobs
Classify the `env` of each task:

- `LD_LIBRARY_PATH`: never recorded (A1).
- `ECCODES_DEFINITION_PATH`, `ECCODES_SAMPLES_PATH`: not recorded as values; they are set **at run
  time from the RPATH of the binary**, so that they always match the ecCodes the binary is linked
  with, on any station and with any pack. The importer only keeps what is specific to the task,
  relative to the ecCodes installation:
  - whether `"$PWD"` comes first in the definition path (64 tasks out of 65);
  - the samples directory (`ifs_samples/grib1_mlgrib2` for all of dv-0408).
  The importer checks that Davai's values are `<prefix>/share/eccodes/...` for the `<prefix>` found
  in the RPATH of the pack's binary; otherwise it reports it.
- `BUFR_TABLES`: not in the RPATH (the tables come from emos, the library from auxlibs); it becomes a
  station variable in `site.sh`. A station without it cannot run the tests that use BUFR (stated in
  the pjob comment).
- Same value as in `site.sh`, or the same in all tasks and machine-independent: dropped (or moved to
  the common part of the job).
- Specific to the task: `export` lines in the pjob.

`generate.pm` gets a function for this:

```bash
# seteccodes [--pwd] BINARY SAMPLES: set ECCODES_DEFINITION_PATH and ECCODES_SAMPLES_PATH for the
# ecCodes in the RPATH (or RUNPATH) of BINARY

function seteccodes
{
  local pwd=""
  if [ "x$1" = "x--pwd" ]
  then
    pwd="$PWD:"
    shift
  fi
  local lib=$(readelf -d $1 | sed -n 's/.*\(RPATH\|RUNPATH\).*\[\(.*\)\]/\2/p' | tr ':' '\n' | \
              while read d; do [ -f $d/libeccodes.so ] && echo $d && break; done)
  if [ "x$lib" = "x" ]
  then
    echo "seteccodes: no libeccodes.so in the RPATH of $1" 1>&2
    exit 1
  fi
  local prefix=$(dirname $lib)
  export ECCODES_DEFINITION_PATH=$pwd$prefix/share/eccodes/definitions
  export ECCODES_SAMPLES_PATH=$prefix/share/eccodes/$2
}
```

It also fits the classic test cases, which today rely on whatever ecCodes the station's environment
provides; that is not part of this proposal.

---

## C. Generation

### C1. Namelists — namelists
In `namelist/<cycle>/` (cycle chosen with `--version`):

- `fort.4` → `DV_<NAME>.nam`. The parallel settings stay; `setnampar` overrides `NPROC`, `NSTRIN`,
  `NSTROUT`, `MBX_SIZE`, `NCOMBFLEN` with the profile's values, as for the other test cases.
- The other text inputs of `rw/` (list in "What dv-0408 contains"; rule: small text file that is a
  namelist, JSON or a known selection file) → `DV_<NAME>.<file>`, e.g.
  `DV_0408_ARPEGE_GLOBAL798C22_FORECAST.xxt00000600`, `DV_0408_ARPEGE_BSM4DVAR_CNT0_MINIM.oops.json`. This
  follows the existing `${CNMEXPL}.selnam_fp_0` convention.
- Everything else in `rw/` stays data (B3).

Keeping the namelists in git is the main benefit of the import: they can be read and edited like
any Mitraillette namelist. Since the names of two experiments differ, `git diff` does not pair
them; the importer report does: for each new test case, it diffs its namelists with those of the
test case of the previous import that has the same name apart from the tag
(`DV_0408_ARPEGE_GLOBAL798C22_FORECAST.nam` → `DV_0512_ARPEGE_GLOBAL798C22_FORECAST.nam`).

### C2. Pjobs, and the `getdavai` function — pjobs + code
A generated pjob:

```bash
# MITRAILLE PROFILE = dv-1x32x4
# MITRAILLE TIME    = 10
# MITRAILLE COMMENT = Davai canonical_arpege_global798c22 / forecast; needs BUFR_TABLES

getdavai dv-0408-belenos@marguina   # ro/ linked, rw/ copied
getnam
$CP namprovi fort.4

seteccodes --pwd $MYOWNBIN ifs_samples/grib1_mlgrib2

mpilaunch $MYOWNBIN       # $BINDIR/OOVAR oops.json, $BINDIR/OOTESTVAR -t b/test_adjoint oops.json

shownode
```

In `generate.pm`:
- `FILE_PATH_DAVAI=${INPUTFILES_HOME}/davai`;
- `getdavai EXPERIMENT`: installs `$FILE_PATH_DAVAI/EXPERIMENT/$CNMEXPL`; for `ro/`, symlinks to the pool
  files (`readlink -f`), since `TMP_BASE` may be on a different file system from Lustre and hard
  links are then impossible; for `rw/`, `cp -RL`; then copies the other `$NAM_PATH/$CNMEXPL.*`
  files (except `.nam`) without the prefix. The pjob does not list them, so it does
  not change when Davai adds or removes a namelist;
- `seteccodes` (B4).

`mpilaunch` already passes its arguments (`$*`), so the OOPS binaries need nothing new.

The experiment can be written in the pjob, since a pjob belongs to one experiment only. Reimporting
the same experiment rewrites its pjobs.

### C3. Profiles — stations
For each Davai layout, the importer uses the existing profile with the same `nnode_fc`, `ntask_fc`
and `nopmp_fc` (and no IO server), and adds a profile only when there is none. On dv-0408:

| Layout | Profile |
|---|---|
| 1x1x1 | `tiny-singlecore` (existing) |
| 1x16x8 | `dv-1x16x8` (new: `small` has 2 nodes) |
| 1x32x4 | `dv-1x32x4` (new) |
| 3x32x4 | `dv-3x32x4` (new) |
| 4x32x4 | `dv-4x32x4` (new) |
| 1x8x4, 1x16x1, 1x4x1 | `dv-1x8x4`, `dv-1x16x1`, `dv-1x4x1` (new) |

`partial` is set only when Davai ran the task in the shared partition (`--partition=shared` in
the `sbatch` options of task.json) and `ntask_fc` x `nopmp_fc` is less than `cores_per_node`
(`machine.conf`); such profiles are named `dv-NxPxO-shared`. Davai runs its tasks on whole nodes
(`--exclusive`, normal256): a partial node job gets 4 GB per core (`sbatch.partial`), and
ALARO1_BC_CANARI (1x4x1, 53 GB) was OOM-killed there. New
rows go to all stations (`meteofrance`, `ecmwf`). Since the layout is Davai's, D1 can compare
the norms exactly; the profile of a test case can be changed later, like any other.

### C4. PRO_FILE — code/pjobs
The `DV_*` entries go to the PRO_FILE of the version, one block per experiment, between comment
lines (the PRO_FILE reader already skips `#` lines):

```
# davimport begin dv-0408-belenos@marguina
DV_0408_ARPEGE_GLOBAL798C22_FORECAST
...
# davimport end dv-0408-belenos@marguina
```

By default, the block of the new experiment replaces the existing `davimport` blocks: the previous
experiment's test cases leave the PRO_FILE (reported), but their pjobs, namelists and data stay
until the maintainer removes them (D2). With `--keep`, the new block is added after the existing
ones, so that two Davai versions run side by side. Reimporting an experiment rewrites its own block
only.
`mitpack --filter ^DV_` then runs them alone (`^DV_0408_` one experiment), and `--filter '^(?!DV_)'` runs only the classic test
cases.

---

## D. Validation and refresh

### D1. Check each import — process + code
After an import, from the pack in `task.json`:
`unset LD_PRELOAD; mitpack --version CY50T1 --filter ^DV_0408_ --reference $FILE_PATH_DAVAI/dv-0408-belenos@marguina`.
The `--reference` option (E2) learns to read `<test>/ref/NODE.001_01` in an experiment directory.
With the same binary and layout, the norms must be identical. A difference means the import lost
something (a file, an environment variable, a namelist). Only test cases that pass are committed.

### D2. Regular imports — process + importer
For each new Davai version:

1. `unset LD_PRELOAD; davpack` in a pack, with the dumper.
2. `davimport --xp ... [--version ...] [--keep]` (report: new and removed tests, namelist diffs with the
   previous import; GB added).
3. D1.
4. `git commit` of `protojobs/DV_*`, `namelist/<cycle>/DV_*`, the PRO_FILE block and the new
   profiles.

Old experiments stay in `$INPUTFILES_HOME/davai` while the maintainer keeps them. To remove one:
`davimport --remove dv-0408-belenos@marguina` deletes its test cases (`protojobs/DV_0408_*`,
`namelist/*/DV_0408_*`, and its PRO_FILE blocks if any), its data directory, then the pool
entries that no experiment references any more. The git changes are left for the maintainer to
commit.

### D3. Other stations — data + stations
Later: sync `davai/` to hendrix with `hendrix-sync.sh` (relative symlinks are supported), and add
`FILE_PATH_DAVAI`'s data and `BUFR_TABLES` to the ECMWF station. Nothing in A-D depends on it.

---

## Suggested order

1. **A1** (dumper writes `task.json`, the exit code, and no longer records `LD_LIBRARY_PATH`);
   rerun Davai on a pack.
2. **B1, B2, B3** on that run, with `--dryrun` first: report only (names, sizes, duplicates,
   absolute paths, profiles).
3. **B4, C1, C2, C3** for three tasks of different kinds: `DV_0408_ARPEGE_GLOBAL798C22_FORECAST`,
   `DV_0408_ARMCU_AROME_NOMINAL`, `DV_0408_ARPEGE_BSM4DVAR_CNT0_MINIM` (OOPS, ODB). Then **D1** on these
   three.
4. All tasks, **C4**, **D2** (`--remove`).
5. **D3**, when wanted.

I would stop after each step, as for `proposals.md`.

## Questions

1. Which pack do imports run from: a reference pack of the cycle (my assumption, A2), or packs like
   this one?

>> any pack

**Applied** in A2; the pack is recorded in `task.json` for D1.

2. Which cycle directory and PRO_FILE take the `DV_*` test cases? Davai runs from a 50t2 pack, and
   `mitpack` maps 50t2 to CY50T1.

>> add an option, let the user decide

**Applied**: `davimport --version`, guessed as in `mitpack` when absent (B).

3. One date per multi-date task (B1), or all of them?

>> all of them

**Applied** in B1 (`--all-dates` is gone).

4. Is the `DV_<derived name>` naming acceptable, and should the names be shorter (Mitraillette
   style, e.g. `DV_GM_FCST_TL798C22`)?

>> yes, DV_ prefix + something close to davai name

**Applied** in B1: Davai job + task. The task path alone gave 7 collisions on dv-0408; job + task
gives 65 distinct names. `names.conf` is gone; the rule is in the importer.

5. Davai's MPI layouts as new profiles (C3), or existing Mitraillette profiles (loses D1's exact
   comparison)?

>> take existing profiles when they exist, add new profiles when required

**Applied** in C3: an existing profile is used when it has the same layout, so D1 still compares
exactly. On dv-0408, only 1x1x1 has one (`tiny-singlecore`).

6. Should the Davai data go to hendrix too (about 50 GB more), and to the ECMWF station?

>> yes, at some point we will do that

**Applied**: D3, last step.

7. Should previous imports stay on disk until `--gc`, or should each import replace the previous
   one immediately?

>> let us names imports with the davai experiment name; it will be up to the mitraillette maintainer to remove old test cases when needed

**Applied**: data in `davai/<experiment>` (B3), the experiment of each test case in
`namelist/<cycle>/DV_*.davai` (C1), removal by hand with `davimport --remove` (D2).

>> LD_LIBRARY_PATH should not be recorded at all ; ECCODES variables should be set by inspecting the rpath of the executable

**Applied** in A1 and B4 (`seteccodes`). Checked on this pack: `MASTERODB`, `OOVAR`, `OOTESTVAR` and
`BATOR` have `<ecCodes>/lib64` in their RPATH, the same ecCodes as Davai's variables.
`BUFR_TABLES` cannot be found this way, so it stays a station variable.

### New questions

8. The experiment of a test case is in `namelist/<cycle>/DV_*.davai` rather than in the pjob, so
   that CY50T1 and CY51 can use different experiments with one pjob (C1). Is that acceptable?

>> I do not understand the question; please elaborate

Elaboration. The question is where a test case records which Davai experiment its data comes from.

In Mitraillette, a test case has **one pjob for all cycles** (`protojobs/<NAME>.pjob`), but **one
set of namelists per cycle** (`namelist/cy50t1/<NAME>.nam`, `namelist/cy51/<NAME>.nam`; the job
reads them from `$NAM_PATH`, which `--version` selects).

The data of a `DV_*` test case is in `davai/<experiment>/<NAME>/`, and differs between cycles.
Example, for `DV_ARPEGE_GLOBAL798C22_FORECAST`:

| Cycle | Imported from | Data |
|---|---|---|
| CY50T1 | `dv-0408-belenos@marguina` (Davai run from a 50t2 pack) | `davai/dv-0408-belenos@marguina/DV_ARPEGE_GLOBAL798C22_FORECAST/` |
| CY51 | a later `dv-0512-belenos@marguina` (Davai run from a 51 pack) | `davai/dv-0512-belenos@marguina/DV_ARPEGE_GLOBAL798C22_FORECAST/` |

Something must tell the job which of these directories to use:

- **In the pjob** (`getdavai dv-0408-belenos@marguina`): the CY51 import would rewrite the
  shared pjob with `dv-0512`, and CY50T1 would then run its CY50T1 namelist on CY51 data. Avoiding
  this would need one pjob per cycle, which Mitraillette does not do.
- **Next to the namelists** (my proposal): `namelist/cy50t1/DV_ARPEGE_GLOBAL798C22_FORECAST.davai`
  contains `dv-0408-belenos@marguina`, and `namelist/cy51/...davai` contains
  `dv-0512-belenos@marguina`. The pjob only says `getdavai`, which reads `$NAM_PATH/$CNMEXPL.davai`.
  Each cycle picks its own data, and an import into one cycle never touches the other.

8b. Is the `.davai` file next to the namelists acceptable?

>> instead, push the davai experiment name inside the job name; this will solve all issues I think

**Applied** in B1 (`DV_0408_...`, `--tag`), C1 (no `.davai`; the report diffs namelists with the
previous import), C2 (`getdavai dv-0408-belenos@marguina` in the pjob), C4 and D2 (`--remove`
also removes the pjobs and namelists).

9. If a binary has no ecCodes in its RPATH (static link, or found through modules), should
   `seteccodes` stop the job (my proposal), or fall back to station variables?

>> abort

**Applied** in B4: `seteccodes` already stops the job (`exit 1`) with a message.

10. When a test case disappears from a new experiment, C4 removes it from the PRO_FILE but keeps its
    pjob and namelists. Should it rather stay in the PRO_FILE, with the old experiment's data?

>> no

**Applied** in C4, unchanged: it leaves the PRO_FILE block, and its pjob and namelists stay until
the maintainer removes them.

11. With the tag in the names, two experiments' test cases could both stay in the PRO_FILE (e.g.
    `DV_0408_*` and `DV_0512_*` side by side, to compare Davai versions). C4 proposes that a new
    import replaces the previous one in the PRO_FILE, as answered in 10. Should `davimport` also
    have a `--keep` option that adds the new block without removing the old one?

>> yes

**Applied** in B (options) and C4: one PRO_FILE block per experiment, between
`# davimport begin/end <experiment>` lines; `--keep` adds the new block next to the old ones.
