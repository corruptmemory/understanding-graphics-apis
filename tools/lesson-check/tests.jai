// Tests for the lesson checker. Run with: first.jai - test tools/lesson-check
//
// Table-driven: GOOD is one well-formed lesson; every case mutates it with one replace and
// names the findings it expects. No GPU, no Gfx_Test.

#import "Basic";
#import "File";
#import "Process";
#import "String";

#load "check.jai";

// The error-recording logger: errors handed to log_error become assertable.
Error_Recorder :: struct { errors: [..] string; }

record_errors :: (message: string, data: *void, info: Log_Info) {
    if info.common_flags & .ERROR {
        rec := cast(*Error_Recorder) data;
        array_add(*rec.errors, copy_string(message));
    }
}

Case :: struct { name: string; from: string; to: string; expect: [] string; }   // expect: one substring per expected finding

CASES :: Case.[
    .{"good",                       "", "", .[]},
    .{"four-endnotes",              "<!-- endnote slot -->", "<details class=\"endnote\"><summary>x</summary>a</details><details class=\"endnote\"><summary>y</summary>b</details>", .["4 endnotes, at most 3"]},
    .{"open-endnote",               "<details class=\"endnote\">", "<details class=\"endnote\" open>", .["endnote is open by default", "endnote is open by default"]},   // both endnotes match
    .{"snippet-neither",            "data-src=\"src/sample.jai:3\"", "", .["snippet has neither data-src nor data-illustrative"]},
    .{"snippet-line-past-end",      "src/sample.jai:3", "src/sample.jai:99", .["snippet 'src/sample.jai:99': line is past the end"]},
    .{"snippet-missing-file",       "src/sample.jai:3", "src/missing.jai:1", .["snippet 'src/missing.jai:1': no such file"]},
    .{"illustrative-with-src",      "data-illustrative=\"d3d12\"", "data-illustrative=\"d3d12\" data-src=\"src/sample.jai:1\"", .["illustrative snippet carries data-src"]},
    .{"step-without-box",           "data-step=\"s2\"", "data-step=\"s1\"", .["step 's2' has no box in the spine"]},
    .{"box-unknown-step",           "data-step=\"s2\"", "data-step=\"nope\"", .["box refers to unknown step 'nope'", "step 's2' has no box in the spine"]},
    .{"duplicate-step-id",          "id=\"s2\"", "id=\"s1\"", .["duplicate step id 's1'", "box refers to unknown step 's2'", "no element with id 's2'"]},
    .{"two-outcomes",               "<li>outcome three</li>", "", .["outcomes has 2 items, want 3"]},
    .{"sidebar-no-term",            " data-term=\"Command buffer\"", "", .["sidebar lacks data-term"]},
    .{"sidebar-no-dl",              "<dl class=\"elsewhere\">", "<dl>", .["sidebar has no dl.elsewhere"]},
    .{"sidebar-unknown-api",        "<dt>D3D12</dt>", "<dt>DirectX 12</dt>", .["sidebar dt 'DirectX 12' is not D3D12 or Metal"]},
    .{"lanes-out-of-order",         "data-lane=\"driver\"", "data-lane=\"gpu\"", .["lanes are [cpu, gpu, gpu], want cpu, driver, gpu"]},
    .{"no-sources",                 "<section class=\"sources\">", "<section class=\"refs\">", .["no sources section"]},
    .{"no-next",                    "<p class=\"next\">", "<p class=\"last\">", .["no next link"]},
    .{"broken-link",                "class=\"see\" href=\"neighbour.html\"", "class=\"see\" href=\"nowhere.html\"", .["link target does not exist: nowhere.html"]},
    .{"broken-fragment",            "href=\"#s2\"", "href=\"#ghost\"", .["no element with id 'ghost'"]},
    .{"no-noscript",                "<noscript>", "<nonscript>", .["no noscript note"]},
    .{"no-article",                 "<article class=\"lesson\"", "<article class=\"page\"", .["no <article class=\"lesson\">"]},
];

Resolve_Case :: struct { page: string; href: string; want: string; }

RESOLVE_CASES :: Resolve_Case.[
    .{"lessons/vulkan/03.html", "../assets/lesson.css",             "lessons/assets/lesson.css"},
    .{"lessons/vulkan/03.html", "./04.html",                        "lessons/vulkan/04.html"},
    .{"index.html",             "lessons/concept-map.html",         "lessons/concept-map.html"},
    .{"lessons/vulkan/03.html", "../../vulkan/exercise-3/README.md", "vulkan/exercise-3/README.md"},
];

PAGE_PATH :: "lessons/vulkan/03-sample.html";

// ---- the landing page ------------------------------------------------------------------

Index_Case :: struct { name: string; from: string; to: string; pages: [] string; expect: [] string; }

INDEX_CASES :: Index_Case.[
    .{"index-good",                "", "", .["lessons/vulkan/00-a.html"], .[]},
    .{"index-ignores-template",    "", "", .["lessons/vulkan/00-a.html", "lessons/_template.html"], .[]},
    .{"index-unlinked-page",       "", "", .["lessons/vulkan/00-a.html", "lessons/vulkan/01-b.html"], .["lesson page not linked from index: lessons/vulkan/01-b.html"]},
    .{"index-rows-out-of-order",   "data-number=\"1\">", "data-number=\"2\">", .["lessons/vulkan/00-a.html"], .["track 'vulkan' rows are [0, 2, 2], want 0..2 in order"]},
    .{"index-done-without-link",   "data-state=\"todo\">lesson", "data-state=\"done\">lesson", .["lessons/vulkan/00-a.html"], .["row 2 says the lesson is done but links nothing"]},
    .{"index-tracks-out-of-order", "data-track=\"directx\"", "data-track=\"metal\"", .["lessons/vulkan/00-a.html"], .["tracks are [vulkan, metal, metal], want vulkan, directx, metal"]},
];

GOOD_INDEX :: #string HTML
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Understanding Graphics APIs</title>
</head>
<body class="site">
<header class="site-head">
<h1>Understanding Graphics APIs</h1>
<p>Vulkan · DirectX · Metal, in Jai</p>
</header>
<section class="tracks">
<article class="track" data-track="vulkan">
<h2>Vulkan <span class="pill live">live · Linux/X11</span></h2>
<div class="lrow" data-number="0"><span class="n">0</span><span class="t"><a href="lessons/vulkan/00-a.html">A</a></span><span class="marks"><span class="mark" data-state="done">lesson</span> · <span class="mark" data-state="todo">exercise</span> · <span class="mark" data-state="todo">tests</span></span></div>
<div class="lrow" data-number="1"><span class="n">1</span><span class="t">B</span><span class="marks"><span class="mark" data-state="current">lesson</span> · <span class="mark" data-state="todo">exercise</span> · <span class="mark" data-state="todo">tests</span></span></div>
<div class="lrow" data-number="2"><span class="n">2</span><span class="t">C</span><span class="marks"><span class="mark" data-state="todo">lesson</span> · <span class="mark" data-state="todo">exercise</span> · <span class="mark" data-state="todo">tests</span></span></div>
<div class="lrow" data-project="1"><span class="n">p1</span><span class="t">Project 1</span><span class="marks"><span class="mark" data-state="todo">brief</span></span></div>
</article>
<article class="track tbd" data-track="directx">
<h2>DirectX 11 / 12 <span class="pill">TBD · Windows</span></h2>
<p>Unlocked when this repo runs on Windows.</p>
</article>
<article class="track tbd" data-track="metal">
<h2>Metal <span class="pill">TBD · macOS</span></h2>
<p>Unlocked when this repo runs on macOS.</p>
</article>
</section>
</body>
</html>
HTML

GOOD :: #string HTML
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Sample lesson</title>
<link rel="stylesheet" href="neighbour.html">
<script src="neighbour.html" defer></script>
</head>
<body>
<article class="lesson" data-track="vulkan" data-number="3">
<header class="lesson-head">
<h1>Sample lesson</h1>
<a class="exercise" href="neighbour.html">exercise-3</a>
</header>
<noscript>Without scripts the panel does not follow the text.</noscript>
<ul class="outcomes">
<li>outcome one</li>
<li>outcome two</li>
<li>outcome three</li>
</ul>
<section class="step" id="s1">
<h2>1. First</h2>
<p>See <a class="see" href="neighbour.html">the neighbour</a> and <a href="#s2">step two</a>.</p>
<pre class="snippet" data-src="src/sample.jai:3"><code>x := 1;</code></pre>
<aside class="sidebar" id="sb-cb" data-term="Command buffer">
<dl class="elsewhere"><dt>D3D12</dt><dd>command list</dd><dt>Metal</dt><dd>command buffer</dd></dl>
<pre class="snippet" data-illustrative="d3d12"><code>list->Close();</code></pre>
</aside>
</section>
<section class="step" id="s2">
<h2>2. Second</h2>
<p>More prose.</p>
</section>
<details class="endnote"><summary>One</summary>a</details>
<details class="endnote"><summary>Two</summary>b</details>
<!-- endnote slot -->
<div class="where">
<div class="strip"></div>
<aside class="spine">
<h2 class="spine-title">Where is this happening?</h2>
<div class="lane" data-lane="cpu"><span class="lane-tag">CPU</span><div class="bar"><button class="box" data-step="s1">first</button><span class="arrow" data-step="s1">→</span></div></div>
<div class="lane" data-lane="driver"><span class="lane-tag">driver</span><div class="bar"><button class="box" data-step="s2">second</button></div></div>
<div class="lane" data-lane="gpu"><span class="lane-tag">GPU</span><div class="bar"></div></div>
</aside>
</div>
<section class="sources"><h2>Sources</h2><ul><li>A source</li></ul></section>
<p class="next"><a href="neighbour.html">Now do exercise 3</a></p>
</article>
</body>
</html>
HTML

passed := 0;
failed := 0;

report :: (name: string, ok: bool, detail: string) {
    if ok {
        print("PASS %\n", name);
        passed += 1;
    } else {
        print("FAIL %: %\n", name, detail);
        failed += 1;
    }
}

describe :: (findings: [] Finding) -> string {
    b: String_Builder;
    for findings  print_to_builder(*b, "\n    %:%: %", it.path, it.line, it.message);
    return builder_to_string(*b);
}

main :: () {
    fixtures := tprint("%fixtures/", #filepath);

    for c: CASES {
        html := GOOD;
        if c.from  html = replace(GOOD, c.from, c.to);
        findings := check_lesson(html, PAGE_PATH, fixtures);

        ok := findings.count == c.expect.count;
        for want: c.expect {
            matched := false;
            for findings  if contains(it.message, want) { matched = true; break; }
            if !matched  ok = false;
        }
        report(c.name, ok, tprint("% findings, want %: %", findings.count, c.expect.count, describe(findings)));
    }

    for c: INDEX_CASES {
        html := GOOD_INDEX;
        if c.from  html = replace(GOOD_INDEX, c.from, c.to);
        findings := check_index(html, fixtures, c.pages);

        ok := findings.count == c.expect.count;
        for want: c.expect {
            matched := false;
            for findings  if contains(it.message, want) { matched = true; break; }
            if !matched  ok = false;
        }
        report(c.name, ok, tprint("% findings, want %: %", findings.count, c.expect.count, describe(findings)));
    }

    for RESOLVE_CASES {
        got := resolve_relative(it.page, it.href);
        report(tprint("resolve % + %", it.page, it.href), got == it.want, tprint("got '%', want '%'", got, it.want));
    }

    report("line_of start",       line_of("a\nb\nc", 0) == 1, tprint("got %", line_of("a\nb\nc", 0)));
    report("line_of second line", line_of("a\nb\nc", 2) == 2, tprint("got %", line_of("a\nb\nc", 2)));
    report("line_of third line",  line_of("a\nb\nc", 4) == 3, tprint("got %", line_of("a\nb\nc", 4)));

    // ---- the concept map --------------------------------------------------------------
    entries := collect_sidebars(fixtures);
    report("collect_sidebars finds the three sidebars in the track pages", entries.count == 3, tprint("got % entries", entries.count));
    if entries.count == 3 {
        report("collect_sidebars sorts by term then lesson",
               entries[0].term == "Fence" && entries[1].term == "Queue" && entries[1].number == "0" && entries[2].number == "1",
               tprint("got %/%, %/%, %/%", entries[0].term, entries[0].number, entries[1].term, entries[1].number, entries[2].term, entries[2].number));
        e := entries[1];
        report("collect_sidebars fills the lesson and api cells",
               e.href == "vulkan/00-a.html#sb-queue" && e.track == "vulkan" && e.lesson_title == "A" && e.d3d12 == "command queue" && e.metal == "MTLCommandQueue",
               tprint("got href '%', track '%', title '%', d3d12 '%', metal '%'", e.href, e.track, e.lesson_title, e.d3d12, e.metal));
    }
    // An unreadable lesson page must be reported through log_error, never skipped: the concept-map
    // verb would otherwise write a map without that lesson's terms and say nothing.
    scratch  := tprint("%.build/unreadable/", #filepath);
    page_dir := tprint("%lessons/vulkan/", scratch);
    make_directory_if_it_does_not_exist(page_dir, recursive = true);
    locked := tprint("%1%2", page_dir, "00-locked.html");   // not "%00-…": a digit after % is a positional argument
    write_entire_file(locked, "<article class=\"lesson\" data-track=\"vulkan\" data-number=\"0\"><h1>Locked</h1></article>");
    run_command("chmod", "000", locked);
    rec: Error_Recorder;
    ctx := context;
    ctx.logger      = record_errors;
    ctx.logger_data = *rec;
    locked_entries: [..] Sidebar_Entry;
    push_context ctx {
        locked_entries = collect_sidebars(scratch);
    }
    run_command("chmod", "644", locked);
    file_delete(locked);
    report("collect_sidebars reports an unreadable page",
           rec.errors.count == 1 && contains(rec.errors[0], "00-locked.html") && locked_entries.count == 0,
           tprint("% errors logged: %; % entries", rec.errors.count, rec.errors, locked_entries.count));

    page := concept_map_html(entries);
    _, rows := replace(page, "<tr><td>", "");
    report("concept_map_html links the lesson", contains(page, "<td><a href=\"vulkan/00-a.html#sb-queue\">vulkan 0: A</a></td>"), page);
    report("concept_map_html has one row per sidebar", rows == 3, tprint("got % rows", rows));
    report("concept_map_html says when there are no sidebars", contains(concept_map_html(.[]), "No sidebars yet."), concept_map_html(.[]));

    js_bad  := check_js("const x = fetch('a')", "spine.js");
    js_good := check_js("const y = 1", "spine.js");
    report("check_js flags fetch",   js_bad.count == 1 && contains(js_bad[0].message, "fetch("), describe(js_bad));
    report("check_js passes plain",  js_good.count == 0, describe(js_good));

    print("% passed, % failed\n", passed, failed);
    if failed > 0  exit(1);
}
