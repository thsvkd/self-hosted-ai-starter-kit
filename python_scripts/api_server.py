from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

# from typing import List
import asyncio
import sys
from pathlib import Path
# import json


class RunScriptRequest(BaseModel):
    script_path: str


app = FastAPI()


@app.post("/run-script")
async def run_script(req: RunScriptRequest):
    script_path = req.script_path
    if not script_path:
        raise HTTPException(status_code=400, detail="Missing 'script_path' parameter")

    p = Path(script_path)
    if not p.exists() or not p.is_file():
        raise HTTPException(status_code=400, detail=f"Script not found: {script_path}")

    # Use the same Python interpreter that's running this server
    python_executable = sys.executable or "python"

    try:
        # 비동기 서브프로세스 실행 (stdout/stderr 수집)
        proc = await asyncio.create_subprocess_exec(
            python_executable,
            str(p),
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )

        stdout_bytes, stderr_bytes = await proc.communicate()
        stdout = stdout_bytes.decode("utf-8", errors="replace") if stdout_bytes else ""
        stderr = stderr_bytes.decode("utf-8", errors="replace") if stderr_bytes else ""

        # Try to parse stdout as JSON to extract output file(s).
        # output_files: List[str] = []
        # try:
        #     parsed = json.loads(stdout.strip()) if stdout.strip() else None
        #     if isinstance(parsed, dict):
        #         if "output_files" in parsed and isinstance(parsed["output_files"], list):
        #             output_files = parsed["output_files"]
        #         elif "output_file" in parsed:
        #             output_files = [parsed["output_file"]]
        # except Exception:
        #     # not JSON or unexpected format — ignore and return stdout as-is
        #     output_files = []

        result = {
            "returncode": proc.returncode,
            "output": stdout,
            "error": stderr,
            # "output_files": output_files,
        }

        if proc.returncode != 0:
            # 스크립트 내부 에러는 500으로 반환 (output_files 포함)
            raise HTTPException(status_code=500, detail=result)

        return result

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail={"error": str(e)})


if __name__ == "__main__":
    # 개발/디버그용으로 직접 실행할 때
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
