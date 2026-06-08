import os
import json
import time
from pathlib import Path
from dotenv import load_dotenv
import openai
from typing import Dict, List, Optional

load_dotenv(Path(__file__).parent / ".env")

client = openai.OpenAI(
    api_key=os.getenv("DEEPSEEK_API_KEY"),
    base_url=os.getenv("DEEPSEEK_BASE_URL", "https://api.deepseek.com")
)


class ApprovalGate:
    """Requires user to type APPROVE before dangerous operations."""
    @staticmethod
    def require(action: str):
        print(f"\n⚠️  ACTION REQUESTED: {action}")
        ans = input("Type APPROVE to continue: ").strip()
        if ans != "APPROVE":
            raise PermissionError("Approval denied. Aborting operation.")


class HermesMatrix:
    """
    Hermes Matrix v5 — Full multi-round adversarial code generation pipeline.

    Per round:
      1. [Architect]  (round 1 only) → API spec / design
      2. [Coder]       → generate or fix code incrementally
      3. [Adversarial] → Red Team attack / Blue Team defense / Judge verdict
      4. [QA]          → functional correctness review
      5. [Security]    → vulnerability review

    If all pass → save & exit.
    If any fails → collect ALL feedback → next round.
    """

    def __init__(self, project_root: str):
        self.project_root = Path(project_root).resolve()
        self.backend_dir = self.project_root / "backend"
        self.state: Dict[str, str] = {}
        self.feedback_history: List[str] = []
        self.gate = ApprovalGate()
        self.max_retries = 3
        self.timeout = 120
        self.model_pro = "deepseek-v4-pro"
        self.model_flash = "deepseek-v4-flash"

    # ── LLM call with retry ────────────────────────────────────────

    def _call(self, model: str, system: str, user: str,
              json_mode=False, temp=0.25) -> str:
        for attempt in range(1, self.max_retries + 1):
            try:
                kwargs = dict(
                    model=model,
                    messages=[
                        {"role": "system", "content": system},
                        {"role": "user", "content": user},
                    ],
                    temperature=temp,
                    timeout=self.timeout,
                )
                if json_mode:
                    kwargs["response_format"] = {"type": "json_object"}

                resp = client.chat.completions.create(**kwargs)
                content = resp.choices[0].message.content.strip()
                if content:
                    return content
                print(f"  \u26a0\ufe0f Attempt {attempt}: Empty response, retrying...")
                time.sleep(2)
            except Exception as e:
                print(f"  \u26a0\ufe0f Attempt {attempt} API Error: {e}, retrying...")
                time.sleep(2)
        print("  \u274c API failed after retries")
        return ""

    # ── Stage 1: Architect ─────────────────────────────────────────

    def _prompt_architect(self, requirement: str) -> str:
        return self._call(
            self.model_pro,
            "You are a senior software architect. Design a clean REST API "
            "for the given requirement. Output ONLY valid OpenAPI 3.1 JSON. "
            "Include all endpoints, request/response schemas, "
            "and security schemes. No extra text.",
            requirement,
            json_mode=True,
            temp=0.1,
        )

    # ── Stage 2: Coder (incremental patch) ─────────────────────────

    def _prompt_coder(self, requirement: str,
                      prev_code: str = "", feedback: str = "") -> str:
        if prev_code and feedback:
            system = (
                "You are a senior FastAPI expert. Fix the code based on "
                "the feedback below.\n\n"
                "PREVIOUS CODE (patch this incrementally, "
                "do NOT rewrite from scratch):\n"
                f"```python\n{prev_code[:4000]}\n```\n\n"
                "FEEDBACK FROM ALL REVIEWERS (fix ALL of these issues):\n"
                f"{feedback}\n\n"
                "CRITICAL RULES:\n"
                "- NEVER hardcode SECRET_KEY. Use os.getenv(\"SECRET_KEY\")\n"
                "- Implement Refresh Token Rotation\n"
                "- Use passlib for passwords, python-jose for JWT\n"
                "- Check user.is_active on login\n"
                "- Proper error handling and logging\n"
                "- Use env vars for all secrets\n\n"
                "Output ONLY the COMPLETE fixed Python code. No markdown."
            )
        else:
            system = (
                "You are a senior FastAPI expert.\n\n"
                "CRITICAL RULES:\n"
                "- NEVER hardcode SECRET_KEY. Use os.getenv(\"SECRET_KEY\")\n"
                "- Implement Refresh Token Rotation\n"
                "- Use passlib for passwords, python-jose for JWT\n"
                "- Check user.is_active on login\n"
                "- Use env vars for all secrets\n"
                "- Proper error handling and logging\n\n"
                "Output ONLY the complete Python FastAPI code. No markdown."
            )

        return self._call(
            self.model_flash, system,
            f"Requirement: {requirement}", temp=0.3,
        )

    # ── Stage 3: Adversarial Review (Red/Blue/Judge) ───────────────

    def _prompt_adversarial(self, code: str) -> dict:
        system = (
            "You are in EXTREME ADVERSARIAL CODE REVIEW MODE.\n\n"
            "You play THREE roles in strict sequence:\n\n"
            "**ROUND 1: Red Team (Attacker)**\n"
            "You are a 15-year veteran security researcher + hacker. "
            "Find 6-8 specific, high-quality attack vectors:\n"
            "- Logic errors, edge cases, boundary failures\n"
            "- Malicious input construction (fuzzing)\n"
            "- Race conditions / deadlocks / data races\n"
            "- Security vulnerabilities (injection, auth bypass, etc.)\n"
            "- Performance disasters (large input, extreme distributions)\n"
            "- Resource exhaustion, DoS\n"
            "- Hidden undefined behavior or platform-specific bugs\n\n"
            "**ROUND 2: Blue Team (Defender & Fixer)**\n"
            "- Respond to each finding (admit or defend)\n"
            "- Propose specific fixes\n"
            "- Output the fixed code (incremental patches only)\n\n"
            "**ROUND 3: Judge (Final Verdict)**\n"
            "Red Team attacks the fixed code again (deeper, more insidious).\n"
            "Then Judge gives final verdict with:\n"
            "- Quality score (0-10)\n"
            "- Production-ready? (Yes/No + reason)\n"
            "- Top 3 remaining risks\n"
            "- Final recommendation\n\n"
            "Output format:\n"
            "## ROUND 1: Red Team Attack\n...\n"
            "## ROUND 2: Blue Team Defense & Fix\n...\n"
            "## ROUND 3: Red Team Counter-Attack + Judge Verdict\n...\n"
            "## FINAL VERDICT\n"
            "Score: X/10 | Production: Yes/No | Top Risks: ..."
        )

        raw = self._call(
            self.model_pro, system,
            f"CODE TO REVIEW:\n\n```python\n{code}\n```",
            temp=0.2,
        )
        return self._parse_adversarial(raw)

    def _parse_adversarial(self, raw: str) -> dict:
        if not raw:
            return {"status": "REJECTED", "score": 0,
                    "summary": "Empty response", "full": ""}

        verdict_section = raw
        if "FINAL VERDICT" in raw:
            verdict_section = raw[raw.index("FINAL VERDICT"):]
        lower = verdict_section.lower()

        # Extract score from "Score: X/10" pattern
        score = 0
        for line in verdict_section.split("\n"):
            if "score" in line.lower() and "/10" in line:
                try:
                    score = int(line.split("/")[0].strip().split()[-1])
                except (ValueError, IndexError):
                    pass

        # Heuristic: score >= 6 is passing
        approved = score >= 6

        return {
            "status": "APPROVED" if approved else "REJECTED",
            "score": score,
            "summary": raw[:500],
            "full": raw,
        }

    # ── Stage 4: QA Review ─────────────────────────────────────────

    def _prompt_qa(self, code: str) -> dict:
        system = (
            "You are a QA engineer. Review the code for functional correctness.\n\n"
            "Check for:\n"
            "- Missing error handling paths\n"
            "- API contract violations (wrong status codes, missing fields)\n"
            "- Logic bugs (wrong comparisons, off-by-one, incorrect conditions)\n"
            "- Missing validation\n"
            "- Race conditions in concurrent code\n"
            "- Incomplete implementations (TODO, stub functions, pass)\n\n"
            'Return JSON ONLY:\n'
            '{"status": "APPROVED" or "REJECTED", '
            '"issues": ["issue1", "issue2", ...]}'
        )
        raw = self._call(self.model_flash, system, code,
                         json_mode=True, temp=0.1)
        return self._parse_json(raw, "QA")

    def _parse_json(self, raw: str, label: str) -> dict:
        if not raw:
            return {"status": "REJECTED",
                    "issues": [f"{label}: Empty response"]}
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            return {"status": "REJECTED",
                    "issues": [f"{label}: JSON parse failed"]}

    # ── Stage 5: Security Review ────────────────────────────────────

    def _prompt_security(self, code: str) -> dict:
        system = (
            "You are a security engineer. Focus on REAL exploitable "
            "vulnerabilities only.\n\n"
            "Check for:\n"
            "- Hardcoded secrets (API keys, passwords, tokens)\n"
            "- Injection vulnerabilities (SQL, command, header)\n"
            "- Authentication/authorization bypass\n"
            "- Sensitive data exposure in logs or error messages\n"
            "- Insecure cryptographic practices\n"
            "- Missing input validation on security-critical paths\n"
            "- Path traversal or unsafe file operations\n\n"
            'Return JSON ONLY:\n'
            '{"status": "APPROVED" or "REJECTED", '
            '"vulnerabilities": ["vuln1", "vuln2", ...]}'
        )
        raw = self._call(self.model_flash, system, code,
                         json_mode=True, temp=0.1)
        return self._parse_json(raw, "Security")

    # ── Feedback collector ─────────────────────────────────────────

    def _extract_issues(self, result: dict) -> str:
        """Extract human-readable issues from any review result."""
        parts = []
        if "issues" in result:
            parts.extend(result["issues"])
        if "vulnerabilities" in result:
            parts.extend(result["vulnerabilities"])
        if "summary" in result and isinstance(result["summary"], str):
            parts.append(result["summary"][:300])
        if "full" in result and result["full"]:
            full = result["full"]
            if "FINAL VERDICT" in full:
                parts.append(full[full.index("FINAL VERDICT"):][:500])
        return "\n".join(parts) if parts else "No specific issues extracted"

    # ── Main execution loop ────────────────────────────────────────

    def execute(self, requirement: str, max_rounds: int = 4):
        print("=" * 60)
        print("  HERMES MATRIX v5 \u2014 Full Adversarial Pipeline")
        print("=" * 60)
        print(f"\nRequirement: {requirement}")
        print(f"Max rounds: {max_rounds}\n")

        self.state["requirement"] = requirement
        self.gate.require("Start HermesMatrix execution")

        for r in range(1, max_rounds + 1):
            print(f"\n{'='*60}")
            print(f"  ROUND {r} of {max_rounds}")
            print(f"{'='*60}\n")

            # ── Stage 1: Architect (round 1 only) ──
            if r == 1:
                print("\U0001f4d0 [Architect] Designing API spec...")
                spec = self._prompt_architect(requirement)
                self.state["api_spec"] = spec
                print(f"  API Spec generated ({len(spec)} chars)")
                self.gate.require("Proceed to code generation")

            # ── Stage 2: Coder ──
            print("\U0001f4bb [Coder] Generating code...")
            prev_code = self.state.get("backend_code", "")
            feedback = "\n\n".join(self.feedback_history)
            code = self._prompt_coder(requirement, prev_code, feedback)
            self.state["backend_code"] = code
            print(f"  Code generated ({len(code)} chars)")
            self.gate.require("Proceed to adversarial review")

            # ── Stage 3: Adversarial Review ──
            print("\u2694\ufe0f [Adversarial] "
                  "Red Team \u2192 Blue Team \u2192 Judge...")
            adv = self._prompt_adversarial(code)
            adv_pass = adv["status"] == "APPROVED"

            if adv_pass:
                print(f"  \u2705 Adversarial PASSED "
                      f"(score: {adv.get('score', '?')}/10)")
            else:
                print(f"  \u274c Adversarial FAILED "
                      f"(score: {adv.get('score', '?')}/10)")

            self.gate.require("Proceed to QA review")

            # ── Stage 4: QA Review ──
            print("\U0001f50d [QA] Functional correctness review...")
            qa = self._prompt_qa(code)
            qa_pass = (qa.get("status") == "APPROVED"
                       and not qa.get("issues"))

            if qa_pass:
                print("  \u2705 QA review PASSED")
            else:
                issues = qa.get("issues", ["No details"])
                print(f"  \u274c QA review FAILED: {issues[:3]}")

            self.gate.require("Proceed to security review")

            # ── Stage 5: Security Review ──
            print("\U0001f512 [Security] Vulnerability review...")
            sec = self._prompt_security(code)
            sec_pass = (sec.get("status") == "APPROVED"
                        and not sec.get("vulnerabilities"))

            if sec_pass:
                print("  \u2705 Security review PASSED")
            else:
                vulns = sec.get("vulnerabilities", ["No details"])
                print(f"  \u274c Security review FAILED: {vulns[:3]}")

            # ── Round decision ──
            all_pass = adv_pass and qa_pass and sec_pass

            if all_pass:
                print(f"\n{'='*60}")
                print("  \U0001f389 ALL REVIEWS PASSED! "
                      f"Round {r} complete.")
                print(f"{'='*60}")
                self.gate.require("Save backend/main.py to disk")
                self._save_files()
                print("\n\u2705 Done! Code saved to backend/main.py")
                return
            else:
                # Collect ALL feedback for next round
                parts = [f"--- Round {r} Feedback ---"]
                if not adv_pass:
                    parts.append("[Adversarial]:\n"
                                 + self._extract_issues(adv)[:1000])
                if not qa_pass:
                    parts.append("[QA]:\n"
                                 + self._extract_issues(qa)[:1000])
                if not sec_pass:
                    parts.append("[Security]:\n"
                                 + self._extract_issues(sec)[:1000])
                self.feedback_history.append("\n\n".join(parts))

                print(f"\n  \u23f3 Round {r} failed. "
                      f"Feedback collected for round {r + 1}.")
                print(f"  Total feedback entries: "
                      f"{len(self.feedback_history)}")

        print(f"\n{'='*60}")
        print(f"  \u274c Max rounds ({max_rounds}) reached "
              "without all reviews passing.")
        print("  No files were written.")
        print(f"{'='*60}")

    def _save_files(self):
        self.backend_dir.mkdir(parents=True, exist_ok=True)
        code = self.state.get("backend_code", "")
        code = code.replace("```python", "").replace("```", "").strip()
        if code:
            (self.backend_dir / "main.py").write_text(code, encoding="utf-8")
            print("\u2705 backend/main.py saved")
        else:
            print("\u26a0\ufe0f Code empty, not saved")


if __name__ == "__main__":
    project_root = Path(__file__).parent.parent
    matrix = HermesMatrix(str(project_root))

    requirement = (
        "Implement JWT user login module with FastAPI backend. "
        "Support Refresh Token rotation (invalidate old token). "
        "Must use environment variable SECRET_KEY, no hardcoding."
    )
    matrix.execute(requirement, max_rounds=4)
