import os
import json
from pathlib import Path
from dotenv import load_dotenv
import openai
from typing import Dict

load_dotenv()

client = openai.OpenAI(
    api_key=os.getenv("DEEPSEEK_API_KEY"),
    base_url=os.getenv("DEEPSEEK_BASE_URL", "https://api.deepseek.com")
)


class HermesMatrix:
    """Hermes Matrix v4 - Backend only + Incremental fix"""

    def __init__(self, project_root: str):
        self.project_root = Path(project_root).resolve()
        self.backend_dir = self.project_root / "backend"
        self.state: Dict[str, str] = {}

    def _call(self, model: str, system: str, user: str, json_mode=False, temp=0.25):
        try:
            resp = client.chat.completions.create(
                model=model,
                messages=[{"role": "system", "content": system}, {"role": "user", "content": user}],
                temperature=temp,
                response_format={"type": "json_object"} if json_mode else {"type": "text"},
                timeout=90
            )
            return resp.choices[0].message.content.strip()
        except Exception as e:
            print(f"API Error: {e}")
            return ""

    def execute(self, requirement: str, max_rounds: int = 4):
        print("🚀 Hermes Matrix v4 (Backend only + Incremental fix) started\n")
        self.state["requirement"] = requirement

        for r in range(1, max_rounds + 1):
            print(f"\n{'='*60}\nRound {r}\n{'='*60}")

            if r == 1:
                print("📐 Generating API Spec...")
                spec_sys = "Output ONLY valid OpenAPI 3.1 JSON. No extra text."
                self.state["api_spec"] = self._call("deepseek-v4-pro", spec_sys, requirement, json_mode=True, temp=0.1)

            print("💻 Generating backend code...")
            # Incremental mode: pass previous code to Coder so it can patch based on existing code
            prev_code = self.state.get("backend_code", "")
            prev_feedback = self.state.get("last_feedback", "")

            if prev_code and prev_feedback:
                backend_sys = f"""You are a senior FastAPI expert fixing code issues.

PREVIOUS CODE (fix this, don't rewrite from scratch):
```python
{prev_code[:3000]}
```

FEEDBACK FROM LAST REVIEW (fix these issues):
{prev_feedback}

CRITICAL RULES:
1. NEVER hardcode SECRET_KEY. Use os.getenv("SECRET_KEY")
2. Implement Refresh Token Rotation: invalidate old token server-side after use
3. Use passlib for passwords, python-jose for JWT
4. Check user.is_active on login
5. Use env vars for all secrets
6. Proper error handling

Output ONLY the COMPLETE fixed Python code. No markdown."""
            else:
                backend_sys = """You are Hermes_Backend_Coder (Senior FastAPI Expert).

CRITICAL RULES:
1. NEVER hardcode SECRET_KEY. Use os.getenv("SECRET_KEY")
2. Implement Refresh Token Rotation: invalidate old token server-side after use
3. Use passlib for passwords, python-jose for JWT
4. Check user.is_active on login
5. Use env vars for all secrets
6. Proper error handling and logging

Output ONLY the complete Python FastAPI code. No markdown."""

            backend_input = f"Requirement: {requirement}"
            self.state["backend_code"] = self._call("deepseek-v4-flash", backend_sys, backend_input, temp=0.3)

            print("🔍 Security review...")
            sec_sys = ("You are a security reviewer. Focus on REAL exploitable bugs only. "
                       "Return JSON: {\"status\": \"APPROVED\" or \"REJECTED\", "
                       "\"vulnerabilities\": []}")
            sec_raw = self._call("deepseek-v4-pro", sec_sys, self.state["backend_code"], json_mode=True, temp=0.1)

            try:
                sec = json.loads(sec_raw) if sec_raw else {}
                vulns = sec.get("vulnerabilities", [])
                approved = sec.get("status") == "APPROVED"
            except:
                vulns = ["JSON parse failed"]
                approved = False

            if approved and not vulns:
                print("\nSecurity review passed! Saving files...")
                self._save_files()
                return
            else:
                summary = " | ".join(str(v) for v in vulns)
                self.state["last_feedback"] = summary
                print(f"Round {r} did not pass")
                print(f"   Issues: {summary}")

        print("\nMax rounds reached without passing.")

    def _save_files(self):
        self.backend_dir.mkdir(parents=True, exist_ok=True)
        code = self.state["backend_code"].replace("```python", "").replace("```", "").strip()
        (self.backend_dir / "main.py").write_text(code, encoding="utf-8")
        print("backend/main.py saved")


if __name__ == "__main__":
    project_root = Path(__file__).parent.parent
    matrix = HermesMatrix(str(project_root))

    requirement = "Implement JWT user login module with FastAPI backend. Support Refresh Token rotation (invalidate old token). Must use environment variable SECRET_KEY, no hardcoding."
    matrix.execute(requirement, max_rounds=4)
