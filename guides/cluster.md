# Daily work on the cluster

Everything lives on the NAS: your code, data, Python environments and results. You edit with VS Code, connected to the jumphost, and you run code in a job with `dev`, which gives you a GPU. Both see the same NAS files, so there is nothing to copy back and forth.

![Your laptop connects to the jumphost, which starts the dev job and training jobs on the RCP cluster. Everything reads and writes your NAS folder.](../figures/all-on-cluster.svg)

This guide assumes you did the [account setup](../README.md#2-set-up-your-account-once), and that your project is a Git repository in your NAS folder, `$NAS_HOME/MY_PROJECT`, with the tutorial's `rcp/` folder in it. Words in CAPITALS are placeholders for your own values.

<details>
<summary>Project not on the NAS yet?</summary>

On the jumphost:

```bash
cd "$NAS_HOME"
git clone YOUR_REPOSITORY_URL MY_PROJECT
```

Use the repository's HTTPS URL (`https://...`). For a private repository, Git asks for your username and personal access token, as set up in [step 2 of the README](../README.md#2-set-up-your-account-once).

</details>

<details>
<summary>No <code>rcp/</code> folder in the project yet?</summary>

On the jumphost, from the project folder:

```bash
rcp-init
```

It adds the `rcp/` folder, the notes for coding assistants and their settings, then shows the `git commit` command to run. It uses the same image and settings as the tutorial. Results go to `$NAS_HOME/outputs/MY_PROJECT`.

You can run `rcp-init` again later to get the tutorial's latest `rcp/`. Your `rcp/project.env` is kept.

</details>

---

## Open the project in VS Code

Press **F1**, type **Connect to Host**, pick **rcp-plain**, then **File → Open Folder…** and enter `/mnt/cvlab/scratch/cvlab/home/YOUR_USERNAME/MY_PROJECT`. Next time, use **File → Open Recent**. The [README](../README.md#vs-code) explains the first connection.

Edit files in VS Code as usual. **Terminal → New Terminal** opens a jumphost terminal in the project folder.

---

## Run code: `dev`

In a VS Code terminal:

```bash
dev
```

You get a shell in a job with a GPU, in your project folder. Run your code as on any Linux machine, for example `python train.py`. Typing `dev` in another terminal gives you a second shell in the same job.

Want several terminals side by side, say one running a script, one watching `nvidia-smi` and one for Git? Run `windows` inside the job. It opens a grid of terminals in the current folder:

```bash
windows 4 bash        # 4 plain terminals
windows 2 claude      # 2 Claude Code sessions (or codex, or half for one of each)
```

If your connection drops, run `dev` again, then `tmux attach -t agents` to get the grid back. The [Coding assistants](agents.md#several-agents-at-once) guide has more on running several assistants at once.

The job holds on to its GPU until you delete it, so when you're done, run `runai delete job dev` on the jumphost.

---

## Long runs: `train`

`dev` stops when you delete it, or after 12 hours at most. For a run that keeps going on its own, even after you log out, use `train`. It takes a job name of your choice, followed by the command you would normally type to run your script.

```bash
train JOB_NAME COMMAND
```

For example, if you would normally run `python train.py --epochs 50`, run this in a jumphost terminal, from your project folder:

```bash
train first-run python train.py --epochs 50
```

This starts a job called `first-run` that runs `python train.py --epochs 50` in your project folder, on its own GPU. To keep an eye on it:

```bash
runai list                    # status of your jobs (Pending means waiting for a free GPU)
tail -n 50 "$NAS_HOME/outputs/MY_PROJECT/runs/first-run/log.txt"   # what your script printed so far
runai delete job first-run    # once it has finished or failed, or to stop it
```

When it starts, `train` prints where the run's files go and how to follow it:

```
Run folder: /mnt/cvlab/scratch/cvlab/home/YOUR_USERNAME/outputs/MY_PROJECT/runs/first-run
Status:     bash rcp/wait.sh first-run done
...
```

Each run gets its own folder, `$NAS_HOME/outputs/MY_PROJECT/runs/first-run/`. In it you'll find `log.txt` with everything your script printed (it stays after you delete the job), `info.txt` with what was run and from which Git commit, and `code/`, the copy of your code that the job runs. Since the job uses that copy, you can keep editing in the meantime. Inside the job, this folder is `$RUN_DIR`, so save your results and checkpoints there.

Each run needs a new name, using only lowercase letters, digits and `-`, like `first-run`, `lr-001` or `run-03`. Names are never reused, so earlier runs are never overwritten.

The cluster can stop a training job and restart it later. Have your script save checkpoints to `$RUN_DIR` regularly and resume from the latest one.

Two things that surprise people:
- **The copy only has the files Git tracks.** Data in a Git-ignored folder (like `data/`) won't be there, so read your data from `$DATA_DIR`.
- **The command runs without a shell**, so `>`, `|`, `&&` and `cd` don't work as typed. Wrap them in `bash -c`: `train run-04 bash -c "cd scripts && python run.py > out.txt"`.

<details>
<summary>Need more GPUs, CPUs or RAM?</summary>

Jobs get 1 GPU, 8 CPUs and 32 GiB of RAM by default. To ask for more, put the sizes in front of the command:

```bash
GPUS=2 CPUS=16 MEMORY=64Gi train big-run python train.py
```

Two GPUs only help if your script is written to use them, for example with `torchrun`. Check the [limits](../README.md#limits-and-gpu-sharing) and only ask for what you'll actually use.

</details>

---

## Python packages

The image has Python and common libraries. Put your project's own packages in a virtual environment in the project folder. Any tool works (`python -m venv`, conda, …). Here we use [uv](https://docs.astral.sh/uv/), which is fast and already in the image. Run this once, inside `dev`:

```bash
uv venv --system-site-packages
uv pip install -r requirements.txt
```

From then on, write `.venv/bin/python` instead of `python`, both in `dev` and with `train`:

```bash
train first-run .venv/bin/python train.py --epochs 50
```

<details>
<summary><code>uv: command not found</code>?</summary>

Your image doesn't include uv. Install it once, inside `dev`:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

</details>

---

## Coding assistants

To use Claude Code or Codex in your project, see [Coding assistants](agents.md).
