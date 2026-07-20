import 'report_models.dart';

/// Renders a self-contained dark-theme HTML report for any Flutter/Patrol project.
class HtmlReportGenerator {
  const HtmlReportGenerator();

  String generate(BatchReport report) {
    final gen = _esc(_fmt(report.generatedAt));
    final passRate = report.passRate;
    final totalScenarios = report.scenarioTotal > 0
        ? report.scenarioTotal
        : (report.targetPassedSum + report.targetFailedSum);
    final passedScenarios = report.scenarioTotal > 0
        ? report.scenarioPassed
        : report.targetPassedSum;
    final failedScenarios = report.scenarioTotal > 0
        ? report.scenarioFailed
        : report.targetFailedSum;
    final allGreen = failedScenarios == 0 && passedScenarios > 0;

    final areas = report.leaves.map((l) => l.area).toSet().toList()..sort();
    final areaOpts = areas
        .map((a) => '<option value="${_esc(a)}">${_esc(a)}</option>')
        .join();

    final targetsTable = StringBuffer();
    for (final t in report.targets) {
      final badge = t.ok ? 'ok' : (t.failed > 0 ? 'bad' : 'muted');
      final label = t.ok
          ? 'Passed'
          : (t.failed > 0 ? 'Failed' : (t.runStatus ?? '—'));
      targetsTable.writeln(
        '<tr><td><code>${_esc(t.label)}</code>'
        '${t.sourceLog != null ? "<div class='log'>${_esc(t.sourceLog!)}</div>" : ""}'
        '${t.targetFile != null ? "<div class='log'>${_esc(t.targetFile!)}</div>" : ""}'
        '</td><td>${t.passed}</td><td>${t.failed}</td><td>${t.resolvedTotal}</td>'
        '<td><span class="badge $badge">${_esc(label)}</span></td></tr>',
      );
    }
    targetsTable.writeln(
      '<tr class="total"><td>TOTAL</td>'
      '<td>${report.targetPassedSum}</td><td>${report.targetFailedSum}</td>'
      '<td>${report.targetPassedSum + report.targetFailedSum}</td>'
      '<td><span class="badge ${allGreen ? "ok" : (failedScenarios > 0 ? "bad" : "muted")}">'
      '${allGreen ? "Passed" : (failedScenarios > 0 ? "Failed" : "—")}'
      '</span></td></tr>',
    );

    final leafTable = StringBuffer();
    for (final leaf in report.leaves) {
      final status = leaf.rollupStatus;
      final badge = switch (status) {
        'Passed' => 'ok',
        'Failed' => 'bad',
        _ => 'muted',
      };
      final cases = StringBuffer('<ul>');
      if (leaf.scenarios.isEmpty) {
        cases.write(
          '<li><span class="tname muted">No executed scenarios matched this leaf</span></li>',
        );
      } else {
        for (final s in leaf.scenarios) {
          final cb = s.isPassed ? 'ok' : (s.isFailed ? 'bad' : 'muted');
          cases.write(
            '<li><span class="tname">${_esc(s.name)}</span> '
            '<span class="badge $cb">${_esc(s.status.label)}</span> '
            '${s.sourceLog != null ? '<span class="log">${_esc(s.sourceLog!)}</span>' : ""}'
            '</li>',
          );
        }
      }
      cases.write('</ul>');
      leafTable.writeln(
        '<tr data-area="${_esc(leaf.area)}" data-status="${_esc(status)}">'
        '<td><span class="pill">${_esc(leaf.area)}</span></td>'
        '<td><code>${_esc(leaf.relativePath)}</code></td>'
        '<td><span class="badge $badge">${_esc(status)}</span></td>'
        '<td>${leaf.passedCount}✓ / ${leaf.failedCount}✗</td>'
        '<td>$cases</td></tr>',
      );
    }

    final execRows = StringBuffer();
    for (final s in report.scenarios) {
      final cb = s.isPassed ? 'ok' : (s.isFailed ? 'bad' : 'muted');
      final st = s.isPassed
          ? 'Passed'
          : (s.isFailed ? 'Failed' : s.status.label);
      execRows.writeln(
        '<tr data-area="${_esc(s.suiteOrTarget ?? "")}" data-status="$st">'
        '<td><span class="pill">${_esc(s.suiteOrTarget ?? "—")}</span></td>'
        '<td>${_esc(s.name)}</td>'
        '<td><span class="badge $cb">${_esc(s.status.label)}</span></td>'
        '<td class="log">${_esc(s.sourceLog ?? "")}</td></tr>',
      );
    }

    final banner = allGreen
        ? '<div class="banner-ok">✓ ALL GREEN — $passedScenarios/$totalScenarios scenarios passed</div>'
        : (failedScenarios > 0
            ? '<div class="banner-bad">✗ $failedScenarios failed · $passedScenarios passed · $totalScenarios total</div>'
            : '');

    final callout = allGreen
        ? '<div class="callout ok"><strong>All green.</strong> Every parsed scenario passed for this batch.</div>'
        : (failedScenarios > 0
            ? '<div class="callout"><strong>Failures:</strong> $failedScenarios scenario(s) failed. Filter leaf table by Failed for details.</div>'
            : '');

    final chips = StringBuffer()
      ..write('<span class="chip">Generated: <strong>$gen</strong></span>')
      ..write(
        '<span class="chip">Project: <strong>${_esc(report.projectName)}</strong></span>',
      );
    if (report.device != null && report.device!.isNotEmpty) {
      chips.write(
        '<span class="chip">Device: <strong>${_esc(report.device!)}</strong></span>',
      );
    }
    if (report.runMode != null) {
      chips.write(
        '<span class="chip">Mode: <strong>${_esc(report.runMode!)}</strong></span>',
      );
    }
    if (report.queueLabel != null) {
      chips.write(
        '<span class="chip">Batch: <strong>${_esc(report.queueLabel!)}</strong></span>',
      );
    }
    chips.write(
      '<span class="chip">Scenarios: <strong>$passedScenarios passed / $failedScenarios failed / $totalScenarios total</strong></span>',
    );
    chips.write(
      '<span class="chip">Leaves: <strong>${report.leaves.length}</strong></span>',
    );

    return '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>Patroller Report — ${_esc(report.projectName)}</title>
<style>
:root {
  --bg: #070b16; --panel: #0f1629; --panel2: #162038; --text: #eef3ff; --muted: #93a0bf;
  --ok: #22c55e; --okbg: rgba(34,197,94,.14); --bad: #ef4444; --badbg: rgba(239,68,68,.16);
  --warn: #f59e0b; --warnbg: rgba(245,158,11,.14); --mutebg: rgba(147,160,191,.12);
  --accent: #7dd3fc; --border: rgba(255,255,255,.08); --shadow: 0 24px 60px rgba(0,0,0,.4);
}
*{box-sizing:border-box}
body{margin:0;font-family:ui-sans-serif,system-ui,-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:var(--text);line-height:1.55;min-height:100vh;
background:radial-gradient(1100px 520px at 8% -8%,rgba(125,211,252,.18),transparent 55%),radial-gradient(900px 480px at 100% 0%,rgba(167,139,250,.16),transparent 50%),radial-gradient(700px 400px at 50% 100%,rgba(34,197,94,.1),transparent 50%),var(--bg)}
.wrap{max-width:1320px;margin:0 auto;padding:36px 22px 72px}
.hero{background:linear-gradient(145deg,rgba(22,32,56,.96),rgba(15,22,41,.92));border:1px solid var(--border);border-radius:22px;padding:30px 34px;box-shadow:var(--shadow);margin-bottom:22px;position:relative;overflow:hidden}
.hero::after{content:"";position:absolute;right:-40px;top:-40px;width:220px;height:220px;background:radial-gradient(circle,rgba(34,197,94,.28),transparent 70%);pointer-events:none}
h1{margin:0 0 8px;font-size:1.85rem;letter-spacing:-.025em}
.sub{color:var(--muted);font-size:.98rem}
.meta{display:flex;flex-wrap:wrap;gap:10px;margin-top:18px}
.chip{background:var(--panel2);border:1px solid var(--border);border-radius:999px;padding:7px 13px;font-size:.82rem;color:var(--muted)}
.chip strong{color:var(--text)}
.grid{display:grid;grid-template-columns:repeat(5,1fr);gap:12px;margin-bottom:22px}
@media(max-width:980px){.grid{grid-template-columns:repeat(2,1fr)}}
.stat{background:var(--panel);border:1px solid var(--border);border-radius:16px;padding:18px 16px;box-shadow:0 8px 24px rgba(0,0,0,.18)}
.stat .n{font-size:1.9rem;font-weight:750;letter-spacing:-.03em}
.stat .l{color:var(--muted);font-size:.7rem;text-transform:uppercase;letter-spacing:.07em;margin-top:2px}
.stat.ok .n{color:var(--ok)}.stat.bad .n{color:var(--bad)}
.panel{background:var(--panel);border:1px solid var(--border);border-radius:18px;padding:20px;margin-bottom:18px;box-shadow:var(--shadow)}
h2{margin:0 0 14px;font-size:1.12rem;letter-spacing:-.01em}
.toolbar{display:flex;flex-wrap:wrap;gap:8px;margin-bottom:14px}
input[type=search],select{background:var(--panel2);border:1px solid var(--border);color:var(--text);border-radius:11px;padding:10px 12px}
input[type=search]{flex:1;min-width:220px}
button.filter{background:var(--panel2);border:1px solid var(--border);color:var(--text);border-radius:11px;padding:10px 12px;cursor:pointer}
button.filter.active{border-color:var(--accent);color:var(--accent)}
table{width:100%;border-collapse:collapse;font-size:.9rem}
th,td{text-align:left;padding:12px 10px;vertical-align:top;border-bottom:1px solid var(--border)}
th{color:var(--muted);font-size:.7rem;text-transform:uppercase;letter-spacing:.06em;position:sticky;top:0;background:var(--panel);z-index:1}
tr.total td{font-weight:700;background:rgba(34,197,94,.06)}
code{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:.78rem;color:#c7d2fe;word-break:break-all}
.badge{display:inline-block;border-radius:999px;padding:3px 10px;font-size:.68rem;font-weight:750;letter-spacing:.04em;text-transform:uppercase}
.badge.ok{background:var(--okbg);color:var(--ok)}.badge.bad{background:var(--badbg);color:var(--bad)}
.badge.muted{background:var(--mutebg);color:var(--muted)}
.pill{display:inline-block;background:var(--panel2);border:1px solid var(--border);border-radius:8px;padding:2px 8px;font-size:.74rem;color:var(--accent);text-transform:capitalize}
ul{margin:0;padding-left:16px}li{margin:4px 0}.tname{color:var(--text)}.tname.muted,.muted{color:var(--muted)}
.log{color:var(--muted);font-size:.7rem;display:block;margin-top:2px}
.note{color:var(--muted);font-size:.88rem}
footer{color:var(--muted);font-size:.8rem;margin-top:28px;text-align:center}
tr.hidden{display:none}
.callout{border-left:4px solid var(--warn);background:var(--warnbg);padding:12px 14px;border-radius:0 12px 12px 0;margin:12px 0 0}
.callout.ok{border-left-color:var(--ok);background:var(--okbg)}
.progress{height:10px;border-radius:999px;background:rgba(255,255,255,.06);overflow:hidden;margin-top:16px}
.progress>span{display:block;height:100%;background:linear-gradient(90deg,var(--ok),#4ade80);width:${passRate.toStringAsFixed(2)}%}
.legend{display:flex;gap:14px;flex-wrap:wrap;margin-top:10px;font-size:.82rem;color:var(--muted)}
.legend i{display:inline-block;width:10px;height:10px;border-radius:50%;margin-right:6px}
.legend .ok i{background:var(--ok)}.legend .bad i{background:var(--bad)}
.banner-ok{display:inline-flex;align-items:center;gap:8px;background:var(--okbg);color:var(--ok);border:1px solid rgba(34,197,94,.35);border-radius:999px;padding:6px 14px;font-weight:700;font-size:.85rem;margin-top:12px}
.banner-bad{display:inline-flex;align-items:center;gap:8px;background:var(--badbg);color:var(--bad);border:1px solid rgba(239,68,68,.35);border-radius:999px;padding:6px 14px;font-weight:700;font-size:.85rem;margin-top:12px}
.brand{font-size:.75rem;color:var(--accent);letter-spacing:.08em;text-transform:uppercase;margin-bottom:6px}
</style>
</head>
<body>
<div class="wrap">
  <header class="hero">
    <div class="brand">Patroller · Patrol HTML Report</div>
    <h1>${_esc(report.projectName)} — Patrol Report</h1>
    <div class="sub">
      Project path <code>${_esc(report.projectPath)}</code>
    </div>
    $banner
    <div class="meta">$chips</div>
    <div class="progress"><span></span></div>
    <div class="legend">
      <span class="ok"><i></i>Passed</span>
      <span class="bad"><i></i>Failed</span>
      <span>Pass rate: <strong>${passRate.toStringAsFixed(1)}%</strong></span>
    </div>
  </header>

  <div class="grid">
    <div class="stat"><div class="n">${report.leaves.length}</div><div class="l">Leaf files</div></div>
    <div class="stat ok"><div class="n">${report.leafPassed}</div><div class="l">Files passed</div></div>
    <div class="stat bad"><div class="n">${report.leafFailed}</div><div class="l">Files failed</div></div>
    <div class="stat ok"><div class="n">$passedScenarios</div><div class="l">Scenarios passed</div></div>
    <div class="stat bad"><div class="n">$failedScenarios</div><div class="l">Scenarios failed</div></div>
  </div>

  <div class="panel">
    <h2>Target / suite results</h2>
    <table>
      <thead><tr><th>Target</th><th>Passed</th><th>Failed</th><th>Total</th><th>Status</th></tr></thead>
      <tbody>$targetsTable</tbody>
    </table>
    $callout
  </div>

  <div class="panel">
    <h2>Leaf files</h2>
    <p class="note">Inventory of <code>*_test.dart</code> under the project test directory (suite entrypoints excluded when detected). Status derived from parsed run logs.</p>
    <div class="toolbar">
      <input id="q" type="search" placeholder="Filter by file, area, or test name…"/>
      <select id="area"><option value="">All areas</option>$areaOpts</select>
      <button class="filter active" data-status="">All</button>
      <button class="filter" data-status="Passed">Passed</button>
      <button class="filter" data-status="Failed">Failed</button>
      <button class="filter" data-status="Not run">Not run</button>
    </div>
    <table id="tbl">
      <thead><tr><th>Area</th><th>File</th><th>Status</th><th>P/F</th><th>Test cases ran</th></tr></thead>
      <tbody>$leafTable</tbody>
    </table>
  </div>

  <div class="panel">
    <h2>Every executed scenario</h2>
    <div class="toolbar">
      <input id="q2" type="search" placeholder="Filter scenarios…"/>
      <button class="filter active" data-status="" data-target="exec">All</button>
      <button class="filter" data-status="Passed" data-target="exec">Passed</button>
      <button class="filter" data-status="Failed" data-target="exec">Failed</button>
    </div>
    <table id="exec">
      <thead><tr><th>Target</th><th>Scenario</th><th>Status</th><th>Source</th></tr></thead>
      <tbody>$execRows</tbody>
    </table>
  </div>

  <footer>
    Generated by <strong>Patroller</strong> · single self-contained HTML · works for any Flutter + Patrol project
  </footer>
</div>
<script>
(function(){
  const q=document.getElementById('q'), area=document.getElementById('area');
  const rows=[...document.querySelectorAll('#tbl tbody tr')];
  let status='';
  document.querySelectorAll('button.filter:not([data-target])').forEach(btn=>btn.addEventListener('click',()=>{
    document.querySelectorAll('button.filter:not([data-target])').forEach(b=>b.classList.remove('active'));
    btn.classList.add('active'); status=btn.dataset.status||''; apply();
  }));
  function apply(){
    const term=(q.value||'').toLowerCase(), a=area.value;
    rows.forEach(r=>{
      const hay=r.innerText.toLowerCase();
      r.classList.toggle('hidden', !((!term||hay.includes(term)) && (!a||r.dataset.area===a) && (!status||r.dataset.status===status)));
    });
  }
  q.addEventListener('input', apply); area.addEventListener('change', apply);
  const q2=document.getElementById('q2');
  const erows=[...document.querySelectorAll('#exec tbody tr')];
  let status2='';
  document.querySelectorAll('button.filter[data-target=exec]').forEach(btn=>btn.addEventListener('click',()=>{
    document.querySelectorAll('button.filter[data-target=exec]').forEach(b=>b.classList.remove('active'));
    btn.classList.add('active'); status2=btn.dataset.status||''; apply2();
  }));
  function apply2(){
    const term=(q2.value||'').toLowerCase();
    erows.forEach(r=>{
      const hay=r.innerText.toLowerCase();
      r.classList.toggle('hidden', !((!term||hay.includes(term)) && (!status2||r.dataset.status===status2)));
    });
  }
  q2.addEventListener('input', apply2);
})();
</script>
</body>
</html>
''';
  }

  String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

  String _fmt(DateTime dt) {
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}
