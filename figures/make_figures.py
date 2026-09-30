"""Draws the tutorial figures as plain SVG. Run: python3 make_figures.py"""

from pathlib import Path

FONT = "system-ui, -apple-system, 'Segoe UI', Helvetica, Arial, sans-serif"
MONO = "ui-monospace, 'SF Mono', Menlo, Consolas, monospace"
INK = "#1f2937"
MUTED = "#6b7280"
LINE = "#4b5563"

# One colour per kind of thing, used the same way in every figure.
STYLES = {
    "laptop":   ("#f9fafb", "#9ca3af"),
    "jumphost": ("#f1f5f9", "#64748b"),
    "job":      ("#eff6ff", "#2563eb"),
    "registry": ("#fffbeb", "#d97706"),
    "git":      ("#f5f3ff", "#7c3aed"),
    "storage":  ("#f3f4f6", "#6b7280"),
}


def svg(width, height, body):
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" height="{height}" font-family="{FONT}">
<defs>
  <filter id="shadow" x="-10%" y="-10%" width="120%" height="140%">
    <feGaussianBlur in="SourceAlpha" stdDeviation="1.5"/>
    <feOffset dy="1.5"/>
    <feComponentTransfer><feFuncA type="linear" slope="0.15"/></feComponentTransfer>
    <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
  <marker id="head" viewBox="0 0 10 10" refX="8.5" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
    <path d="M1,1 L9,5 L1,9 Z" fill="{LINE}"/>
  </marker>
  <marker id="head-muted" viewBox="0 0 10 10" refX="8.5" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
    <path d="M1,1 L9,5 L1,9 Z" fill="#9ca3af"/>
  </marker>
</defs>
<rect width="100%" height="100%" rx="12" fill="#ffffff"/>
{body}
</svg>
"""


def text(x, y, s, size=12.5, color=MUTED, weight=None, mono=False, anchor="middle"):
    family = f' font-family="{MONO}"' if mono else ""
    bold = f' font-weight="{weight}"' if weight else ""
    return f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-size="{size}"{bold}{family} fill="{color}" xml:space="preserve">{s}</text>'


def box(x, y, w, h, title, lines=(), kind="laptop", mono_lines=False, mono_title=False):
    fill, stroke = STYLES[kind]
    cx = x + w / 2
    total = 19 + 17 * len(lines)
    ty = y + (h - total) / 2 + 14
    out = [f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="10" fill="{fill}" stroke="{stroke}" stroke-width="1.5" filter="url(#shadow)"/>',
           text(cx, ty, title, size=15, color=INK, weight=600, mono=mono_title)]
    for i, line in enumerate(lines):
        out.append(text(cx, ty + 19 + 17 * i, line, mono=mono_lines))
    return "\n".join(out)


def stack(x, y, w, h, title, lines=(), kind="job", mono_title=False):
    """Several cards on top of each other: 'one or more of these'."""
    fill, stroke = STYLES[kind]
    back = [f'<rect x="{x + d}" y="{y + d}" width="{w}" height="{h}" rx="10" fill="{fill}" stroke="{stroke}" stroke-width="1.2" opacity="0.6"/>'
            for d in (12, 6)]
    return "\n".join(back + [box(x, y, w, h, title, lines, kind, mono_title=mono_title)])


def region(x, y, w, h, label):
    return "\n".join([
        f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="14" fill="none" stroke="#cbd5e1" stroke-width="1.5" stroke-dasharray="6 5"/>',
        text(x + 16, y + 22, label, size=11, color="#64748b", weight=700, anchor="start"),
    ])


def storage(x, y, w, h, title, sub, mono_sub=True):
    fill, stroke = STYLES["storage"]
    rx, ry = w / 2, 10
    cx = x + rx
    return "\n".join([
        f'<path d="M{x},{y} V{y + h} A{rx},{ry} 0 0 0 {x + w},{y + h} V{y}" fill="{fill}" stroke="{stroke}" stroke-width="1.5" filter="url(#shadow)"/>',
        f'<ellipse cx="{cx}" cy="{y}" rx="{rx}" ry="{ry}" fill="#fafafa" stroke="{stroke}" stroke-width="1.5"/>',
        text(cx, y + h / 2 + 8, title, size=15, color=INK, weight=600),
        text(cx, y + h / 2 + 27, sub, mono=mono_sub),
    ])


def tag(x, y, s, mono=False):
    """An arrow label on a small white pill, so it stays readable over lines."""
    width = len(s) * (7.6 if mono else 6.9) + 14
    return "\n".join([
        f'<rect x="{x - width / 2}" y="{y - 11}" width="{width}" height="20" rx="10" fill="#ffffff" stroke="#e5e7eb"/>',
        text(x, y + 3.5, s, size=12, color=LINE, mono=mono),
    ])


def arrow(x1, y1, x2, y2, label="", at=0.5, both=False, dashed=False, mono=False):
    color, head = ("#9ca3af", "head-muted") if dashed else (LINE, "head")
    dash = ' stroke-dasharray="5 4"' if dashed else ""
    start = f' marker-start="url(#{head})"' if both else ""
    out = [f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="1.6"{dash}{start} marker-end="url(#{head})"/>']
    if label:
        out.append(tag(x1 + (x2 - x1) * at, y1 + (y2 - y1) * at, label, mono=mono))
    return "\n".join(out)


figures = {
    # README: the whole picture.
    "all-on-cluster.svg": svg(900, 470, "\n".join([
        box(30, 165, 160, 90, "Your laptop", ["VS Code, terminal"], "laptop"),
        box(262, 165, 170, 90, "Jumphost", ["edit code,", "start jobs: dev, train"], "jumphost"),
        region(500, 104, 370, 222, "RCP CLUSTER"),
        box(520, 134, 330, 72, "dev job", ["your shell and AI agents, 1 GPU"], "job"),
        stack(520, 226, 318, 72, "Training jobs", ["one GPU each, keep running after you log out"], "job"),
        box(605, 18, 160, 56, "Harbor", ["image registry"], "registry"),
        storage(190, 368, 680, 72, "Your NAS folder", ".home  ·  MY_PROJECT  ·  datasets  ·  outputs"),
        arrow(190, 210, 260, 210, "ssh"),
        arrow(432, 210, 498, 210, "runai"),
        arrow(685, 74, 685, 102, ""),
        tag(722, 89, "image"),
        arrow(347, 255, 347, 362, "files", both=True, dashed=True),
        arrow(685, 326, 685, 362, "", both=True, dashed=True),
        tag(722, 344, "files"),
    ])),

    # agents.md: parallel agents in worktrees, each launching its own runs.
    "agents.svg": svg(900, 440, "\n".join([
        region(30, 30, 420, 260, "DEV JOB  ·  ONE TMUX PANE PER AGENT"),
        box(50, 70, 180, 110, "Agent 1", ["worktree", "renderer"], "job"),
        box(250, 70, 180, 110, "Agent 2", ["worktree", "algorithm"], "job"),
        text(240, 222, "quick tests on the job's GPU", size=12.5),
        text(240, 242, "long runs go to training jobs", size=12.5),
        box(560, 40, 300, 58, "renderer-lr-001", ["training job, own GPU"], "job", mono_title=True),
        box(560, 120, 300, 58, "renderer-lr-002", ["training job, own GPU"], "job", mono_title=True),
        box(560, 200, 300, 58, "algorithm-run-01", ["training job, own GPU"], "job", mono_title=True),
        arrow(450, 110, 558, 69, ""),
        arrow(450, 140, 558, 149, "train", at=0.45, mono=True),
        arrow(450, 170, 558, 229, ""),
        storage(30, 340, 830, 70, "outputs/MY_PROJECT/runs/", "one folder per run: log.txt, info.txt, code/, your results", mono_sub=False),
        arrow(710, 258, 710, 334, "", dashed=True),
        tag(770, 297, "logs, results"),
        arrow(240, 290, 240, 334, "", dashed=True),
        tag(300, 312, "read results"),
    ])),

    # images.md: the image contains the code, the NAS only data and results.
    "laptop-with-gpu.svg": svg(820, 380, "\n".join([
        box(30, 110, 160, 80, "Your laptop", ["Docker (optional)"], "laptop"),
        box(320, 24, 180, 64, "Harbor", ["image with your code"], "registry"),
        box(320, 170, 180, 70, "Jumphost", ["start jobs"], "jumphost"),
        box(610, 170, 180, 70, "Job", ["runs the code in /app"], "job"),
        storage(610, 296, 180, 54, "NAS", "data, results"),
        arrow(190, 128, 318, 64, "docker push", dashed=True),
        arrow(190, 172, 318, 200, "ssh"),
        arrow(500, 64, 640, 168, "image", at=0.45),
        arrow(500, 205, 608, 205, "runai"),
        arrow(700, 240, 700, 290, "", both=True, dashed=True),
    ])),

    # hybrid.md: Git carries code and notes between laptop and jumphost.
    "hybrid.svg": svg(860, 400, "\n".join([
        box(240, 24, 220, 64, "Git repository", ["GitHub or GitLab"], "git"),
        box(30, 170, 180, 72, "Your laptop", ["your own copy"], "laptop"),
        box(400, 170, 180, 72, "Jumphost", ["copy on the NAS"], "jumphost"),
        box(650, 170, 180, 72, "Jobs", ["dev, AI agents, training"], "job"),
        storage(420, 318, 410, 56, "Your NAS folder", "code, data, results"),
        arrow(290, 88, 150, 168, "push / pull", both=True),
        arrow(410, 88, 470, 168, "push / pull", both=True),
        arrow(580, 206, 648, 206, "runai"),
        arrow(490, 242, 490, 312, "", both=True, dashed=True),
        arrow(740, 242, 740, 312, "", both=True, dashed=True),
    ])),

    # jupyter.md: two tunnels, laptop -> jumphost (ssh) and jumphost -> job (runai).
    "port-forwarding.svg": svg(1020, 150, "\n".join([
        box(20, 30, 210, 84, "Browser on laptop", ["127.0.0.1:18888"], "laptop", mono_lines=True),
        box(405, 30, 210, 84, "Jumphost", ["127.0.0.1:YOUR_PORT"], "jumphost", mono_lines=True),
        box(790, 30, 210, 84, "Jupyter in a job", ["port 8888"], "job", mono_lines=True),
        arrow(230, 72, 403, 72, "ssh -L", mono=True),
        arrow(615, 72, 788, 72, "runai port-forward", mono=True),
        text(317, 108, "run on your laptop", size=11.5),
        text(702, 108, "run on the jumphost", size=11.5),
    ])),
}

here = Path(__file__).parent
for name, content in figures.items():
    (here / name).write_text(content)
    print("wrote", name)
