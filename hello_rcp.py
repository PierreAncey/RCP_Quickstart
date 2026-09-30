"""First job: check that the job sees the NAS and can write results there."""

import os
import socket
from pathlib import Path

output_dir = Path(os.environ["OUTPUT_DIR"])
output_dir.mkdir(parents=True, exist_ok=True)
result = output_dir / "hello-rcp.txt"

message = f"Hello from {socket.gethostname()}, running in {Path.cwd()}\n"
result.write_text(message)
print(message, end="")
print(f"Saved to {result}")
