#!/usr/bin/env python3
"""PhantomVox AI — 魅影音画 智能创作套件入口"""

import sys
import argparse

from core.engine import Engine
from modules.i18n import _
from modules.hardware import TIER_LABELS


def cmd_info(engine: Engine):
    """显示系统信息"""
    spec = engine.hardware.detect()
    tier = spec.max_tier()

    print(f"\n  {engine.t('app.name')}  ({engine.t('app.tagline')})")
    print(f"  {'=' * 48}")
    print(f"  {engine.t('hardware.cpu')}:     {spec.cpu_model}")
    print(f"  {engine.t('hardware.cpu_cores')}: {spec.cpu_cores}c/{spec.cpu_threads}t")
    print(f"  {engine.t('hardware.ram_total')}: {spec.ram_total_gb:.0f} GB")
    if spec.gpu_models:
        for i, g in enumerate(spec.gpu_models):
            print(f"  {engine.t('hardware.gpu')}:    {g} ({spec.gpu_vram_gb[i]:.0f} GB)")
    else:
        print(f"  {engine.t('hardware.gpu')}:    {engine.t('hardware.gpu_none')}")
    print(f"  {engine.t('hardware.disk_free')}: {spec.disk_free_gb:.0f} GB")
    print(f"  OS:      {spec.os_name} {spec.os_version}")
    print(f"  {engine.t('hardware.model_tier_map')}: T{tier} ({TIER_LABELS[tier]})")
    print(f"  {engine.t('model.title')}:   {engine.i18n.current}")
    print(f"  {engine.t('common.loading')}: {len(engine.modules)}")
    print()


def cmd_locale(engine: Engine, args: argparse.Namespace):
    """语言管理"""
    if args.list:
        print(f"\n  {engine.t('model.tts_models')} ({len(engine.i18n.available)}):")
        for loc in engine.i18n.available:
            from modules.i18n.locales import LOCALE_METADATA
            meta = LOCALE_METADATA.get(loc, {})
            flag = meta.get("flag", "")
            name = meta.get("native_name", loc)
            mark = " ◀" if loc == engine.i18n.current else ""
            print(f"    {flag} {name:14s}  ({loc}){mark}")
        print()
    if args.set:
        try:
            old = engine.i18n.current
            engine.i18n.set_locale(args.set)
            print(f"  {engine.t('system.locale_changed', locale=args.set)}")
        except ValueError as e:
            print(f"  Error: {e}")


def cmd_hardware(engine: Engine, args: argparse.Namespace):
    """硬件检测报告"""
    if args.check:
        model_key = args.check
        spec = engine.hardware.detect()
        ok, reason = spec.can_run_model(model_key)
        status = engine.t("hardware.can_run") if ok else engine.t("hardware.cannot_run")
        print(f"  {model_key}: {status}")
        print(f"  {reason}")
        return

    # 完整报告
    r = engine.hardware.report()
    spec = r["spec"]

    print(f"\n  ═══ {engine.t('hardware.report_title')} ═══")
    print(f"  {engine.t('hardware.cpu')}:     {spec['cpu_model']}")
    print(f"  {engine.t('hardware.cpu_cores')}: {spec['cpu_cores']} ({spec['cpu_threads']} threads)")
    print(f"  {engine.t('hardware.ram')}:    {spec['ram_total_gb']:.1f} GB (avail: {spec['ram_available_gb']:.1f} GB)")
    print(f"  {engine.t('hardware.gpu')}:    {spec['gpu_models'] or engine.t('hardware.gpu_none')}")
    print(f"  {engine.t('hardware.disk')}:   {spec['disk_free_gb']:.0f} GB free")
    print(f"  {engine.t('hardware.os')}:     {spec['os_name']} {spec['os_version']}")
    print(f"  {engine.t('hardware.model_tier_map')}: {r['max_tier_label']}")
    print()

    # 模型兼容性
    print(f"  --- {engine.t('hardware.model_tier_map')} ---")
    for name, info in sorted(r["can_run_models"].items()):
        status = "✓" if info["can_run"] else "✗"
        print(f"  {status} T{info['required_tier']} [{info['type']:6s}] {name}")
    print()

    if r["upgrade_suggestions"]:
        print(f"  --- {engine.t('hardware.upgrade_hint')} ---")
        for s in r["upgrade_suggestions"]:
            print(f"  > {s}")
        print()


def main():
    parser = argparse.ArgumentParser(
        prog="phantomvox",
        description="PhantomVox AI — Intelligent Audio-Video Creation Suite",
    )
    parser.add_argument("--locale", "-l", default=None, help="Startup language (e.g. zh_CN, en, ja)")
    parser.add_argument("--info", action="store_true", help="Show system info")

    sub = parser.add_subparsers(dest="command")

    # locale subcommand
    p_loc = sub.add_parser("locale", help="Language management")
    p_loc.add_argument("--list", action="store_true", help="List available languages")
    p_loc.add_argument("--set", type=str, default=None, help="Switch language")

    # hardware subcommand
    p_hw = sub.add_parser("hardware", help="Hardware detection")
    p_hw.add_argument("--check", type=str, default=None,
                      help="Check model compatibility (e.g. f5_tts)")
    p_hw.add_argument("--report", action="store_true", help="Full hardware report")

    args = parser.parse_args()

    # ── 启动引擎 ──────────────────────────────────────
    engine = Engine(locale=args.locale)

    # ── 注册音频引擎 ──────────────────────────────────
    from modules.audio import AudioEngine
    from modules.audio.providers.edge_tts import EdgeTTSProvider
    from modules.audio.providers.suno import SunoProvider
    from modules.audio.providers.musicgen import MusicGenProvider

    audio = AudioEngine(hardware=engine.hardware)
    audio.register_tts("edge_tts", EdgeTTSProvider())
    audio.register_music("suno", SunoProvider())
    audio.register_music("musicgen_small", MusicGenProvider(model_size="small"))
    engine.register("audio", audio)

    # ── 注册 Agent 引擎 ─────────────────────────────────
    from modules.agent import AgentEngine
    from modules.agent.panels.chat import ChatPanel, ThinkPanel, ImageGenPanel, VideoGenPanel, CodeGenPanel

    agent_engine = AgentEngine(engine=engine)
    agent_engine.register_panel("chat", ChatPanel())
    agent_engine.register_panel("think", ThinkPanel())
    agent_engine.register_panel("image_gen", ImageGenPanel())
    agent_engine.register_panel("video_gen", VideoGenPanel())
    agent_engine.register_panel("code_gen", CodeGenPanel())
    engine.register("agent", agent_engine)

    # ── 注册模型配置 ───────────────────────────────────
    from modules.modelconfig import ConfigManager
    config_mgr = ConfigManager()
    engine.register("config", config_mgr)

    # ── Timeline 引擎 ────────────────────────────────────
    from modules.timeline import TimelineEngine
    timeline_engine = TimelineEngine()
    engine.register("timeline", timeline_engine)

    # ── CodeGen 引擎 (P6) ───────────────────────────────
    from modules.codegen import CodeGenEngine
    codegen_engine = CodeGenEngine()
    engine.register("codegen", codegen_engine)

    # ── VideoGen 引擎 (P6) ──────────────────────────────
    from modules.videogen import VideoGenEngine
    videogen_engine = VideoGenEngine()
    engine.register("videogen", videogen_engine)

    if args.info:
        cmd_info(engine)
        return

    if args.command == "locale":
        cmd_locale(engine, args)
    elif args.command == "hardware":
        cmd_hardware(engine, args)
    else:
        # 默认: 显示帮助
        parser.print_help()
        print(f"\n  {engine.t('app.name')} — {engine.t('app.tagline')}")
        print(f"  {'─' * 40}")
        print(f"  python3 main.py --info          # {engine.t('hardware.hardware_report')}")
        print(f"  python3 main.py locale --list   # {engine.t('model.tts_models')}")
        print(f"  python3 main.py locale --set en # {engine.t('system.locale_changed', locale='en')}")
        print(f"  python3 main.py hardware        # {engine.t('hardware.report_title')}")
        print()


if __name__ == "__main__":
    main()
