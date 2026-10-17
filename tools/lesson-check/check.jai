// The lesson checker: the markup contract from docs/superpowers/plans/2026-10-16-lesson-web-shell.md
// as rules over a tag scanner. #loaded by first.jai (the check-lessons verb) and by tests.jai.
//
// This is a tag scanner, not an HTML parser: authored pages are well formed, and every rule only
// needs open tags, their attributes, and the text between an open tag and its closing tag.

#import "Basic";
#import "File";
#import "File_Utilities";
#import "Sort";
#import "String";

Finding :: struct { path: string; line: int; message: string; }   // line is 1-based, 0 when unknown

// ---- the contract ------------------------------------------------------------------------------

add :: (findings: *[..] Finding, page_path: string, html: string, offset: int, message: string) {
    array_add(findings, .{page_path, line_of(html, offset), message});
}

check_lesson :: (html: string, page_path: string, root: string) -> [..] Finding {
    findings: [..] Finding;

    // article
    articles := collect(html, "article", "lesson");
    if articles.count == 0 {
        add(*findings, page_path, html, 0, "no <article class=\"lesson\">");
    } else {
        if articles.count > 1  add(*findings, page_path, html, articles[1].start, "more than one <article class=\"lesson\">");
        a := articles[0];
        _, has_track  := attr(a, "data-track");
        _, has_number := attr(a, "data-number");
        if !has_track   add(*findings, page_path, html, a.start, "article lacks data-track");
        if !has_number  add(*findings, page_path, html, a.start, "article lacks data-number");
    }

    // header
    headers := collect(html, "header", "lesson-head");
    if headers.count == 0 {
        add(*findings, page_path, html, 0, "no <header class=\"lesson-head\">");
    } else {
        h := headers[0];
        body := inner(html, h);
        if collect(body, "h1", "").count == 0        add(*findings, page_path, html, h.start, "header has no h1");
        if collect(body, "a", "exercise").count == 0  add(*findings, page_path, html, h.start, "header has no exercise link");
    }

    // outcomes
    outcomes := collect(html, "ul", "outcomes");
    if outcomes.count == 0 {
        add(*findings, page_path, html, 0, "no <ul class=\"outcomes\">");
    } else {
        n := collect(inner(html, outcomes[0]), "li", "").count;
        if n != 3  add(*findings, page_path, html, outcomes[0].start, tprint("outcomes has % items, want 3", n));
    }

    // steps
    steps := collect(html, "section", "step");
    step_ids: [..] string;
    if steps.count == 0  add(*findings, page_path, html, 0, "no <section class=\"step\">");
    for steps {
        id, has_id := attr(it, "id");
        if !has_id {
            add(*findings, page_path, html, it.start, "step without id");
            continue;
        }
        if array_find(step_ids, id)  add(*findings, page_path, html, it.start, tprint("duplicate step id '%'", id));
        else                         array_add(*step_ids, id);
        if collect(inner(html, it), "h2", "").count == 0  add(*findings, page_path, html, it.start, tprint("step '%' has no h2", id));
    }

    check_snippets(html, page_path, root, *findings);
    check_sidebars(html, page_path, *findings);
    check_endnotes(html, page_path, *findings);

    // the where container, the strip, the spine
    wheres := collect(html, "div", "where");
    if wheres.count == 0 {
        add(*findings, page_path, html, 0, "no .where container");
    } else {
        if wheres.count > 1  add(*findings, page_path, html, wheres[1].start, "more than one .where container");
        w := wheres[0];
        body := inner(html, w);
        strips := collect(body, "div", "strip");
        spines := collect(body, "aside", "spine");
        if strips.count == 0 || spines.count == 0 {
            add(*findings, page_path, html, w.start, ".where lacks .strip or .spine");
        } else if trim(inner(body, strips[0])).count > 0 {
            add(*findings, page_path, html, w.start, ".strip must be empty in the source (spine.js fills it)");
        }
    }

    // lanes
    lanes := collect(html, "div", "lane");
    names: [..] string;
    for lanes {
        name, _ := attr(it, "data-lane");
        array_add(*names, name);
        body := inner(html, it);
        if collect(body, "span", "lane-tag").count == 0 || collect(body, "div", "bar").count == 0 {
            add(*findings, page_path, html, it.start, tprint("lane '%' lacks .lane-tag or .bar", name));
        }
    }
    if !(names.count == 3 && names[0] == "cpu" && names[1] == "driver" && names[2] == "gpu") {
        at := ifx lanes.count > 0 then lanes[0].start else 0;
        add(*findings, page_path, html, at, tprint("lanes are [%], want cpu, driver, gpu", join(..names, separator = ", ")));
    }

    // boxes and arrows
    boxed: [..] string;
    for collect(html, "button", "box") {
        step, has_step := attr(it, "data-step");
        if !has_step {
            add(*findings, page_path, html, it.start, "box without data-step");
            continue;
        }
        if array_find(step_ids, step)  array_add(*boxed, step);
        else                           add(*findings, page_path, html, it.start, tprint("box refers to unknown step '%'", step));
    }
    for collect(html, "span", "arrow") {
        step, has_step := attr(it, "data-step");
        if !has_step {
            add(*findings, page_path, html, it.start, "arrow without data-step");
            continue;
        }
        if !array_find(step_ids, step)  add(*findings, page_path, html, it.start, tprint("arrow refers to unknown step '%'", step));
    }
    for step_ids  if !array_find(boxed, it)  add(*findings, page_path, html, 0, tprint("step '%' has no box in the spine", it));

    check_sources(html, page_path, *findings);

    // next
    nexts := collect(html, "p", "next");
    if nexts.count == 0 {
        add(*findings, page_path, html, 0, "no next link");
    } else if collect(inner(html, nexts[0]), "a", "").count == 0 {
        add(*findings, page_path, html, nexts[0].start, "next has no link");
    }

    // noscript
    if collect(html, "noscript", "").count == 0  add(*findings, page_path, html, 0, "no noscript note");

    // links
    for check_links(html, page_path, root)  array_add(*findings, it);

    return findings;
}

// ---- rules shared by lessons and deep dives ----------------------------------------------------

// Every snippet carries data-src="path:line" (the path exists under root, the line is in range) or
// data-illustrative, never both.
check_snippets :: (html: string, page_path: string, root: string, findings: *[..] Finding) {
    for collect(html, "pre", "snippet") {
        src, has_src     := attr(it, "data-src");
        _,   illustrative := attr(it, "data-illustrative");
        if illustrative && has_src {
            add(findings, page_path, html, it.start, "illustrative snippet carries data-src");
        } else if !illustrative && !has_src {
            add(findings, page_path, html, it.start, "snippet has neither data-src nor data-illustrative");
        } else if has_src {
            colon := find_index_from_right(src, #char ":");
            line_text := ifx colon >= 0 then slice(src, colon + 1, src.count - colon - 1) else "";
            line, parsed, remainder := string_to_int(line_text);
            if colon < 0 || !parsed || remainder.count > 0 {
                add(findings, page_path, html, it.start, tprint("snippet '%': data-src must be path:line", src));
                continue;
            }
            file := tprint("%1%2", root, slice(src, 0, colon));
            if !file_exists(file) {
                add(findings, page_path, html, it.start, tprint("snippet '%': no such file", src));
                continue;
            }
            text, ok := read_entire_file(file, log_errors = false);
            if !ok {
                add(findings, page_path, html, it.start, tprint("snippet '%': could not read the file", src));
                continue;
            }
            if line < 1 || line > count_lines(text)  add(findings, page_path, html, it.start, tprint("snippet '%': line is past the end", src));
        }
    }
}

// Every sidebar has an id, a term, and a dl.elsewhere whose dt cells are the two map columns.
check_sidebars :: (html: string, page_path: string, findings: *[..] Finding) {
    for collect(html, "aside", "sidebar") {
        _, has_id   := attr(it, "id");
        _, has_term := attr(it, "data-term");
        if !has_id    add(findings, page_path, html, it.start, "sidebar lacks id");
        if !has_term  add(findings, page_path, html, it.start, "sidebar lacks data-term");
        body := inner(html, it);
        dls := collect(body, "dl", "elsewhere");
        if dls.count == 0 {
            add(findings, page_path, html, it.start, "sidebar has no dl.elsewhere");
        } else {
            pairs := inner(body, dls[0]);
            if collect(pairs, "dt", "").count == 0 || collect(pairs, "dd", "").count == 0 {
                add(findings, page_path, html, it.start, "sidebar's dl.elsewhere has no dt/dd pair");
            }
            for dt: collect(pairs, "dt", "") {   // the concept map only knows these two columns
                api := trim(inner(pairs, dt));
                if api != "D3D12" && api != "Metal"  add(findings, page_path, html, it.start, tprint("sidebar dt '%' is not D3D12 or Metal", api));
            }
        }
    }
}

// At most three endnotes, each closed by default, each with a summary.
check_endnotes :: (html: string, page_path: string, findings: *[..] Finding) {
    endnotes := collect(html, "details", "endnote");
    if endnotes.count > 3  add(findings, page_path, html, endnotes[3].start, tprint("% endnotes, at most 3", endnotes.count));
    for endnotes {
        _, open := attr(it, "open");
        if open  add(findings, page_path, html, it.start, "endnote is open by default");
        if collect(inner(html, it), "summary", "").count == 0  add(findings, page_path, html, it.start, "endnote has no summary");
    }
}

// A sources section with at least one entry.
check_sources :: (html: string, page_path: string, findings: *[..] Finding) {
    sources := collect(html, "section", "sources");
    if sources.count == 0 {
        add(findings, page_path, html, 0, "no sources section");
    } else if collect(inner(html, sources[0]), "li", "").count == 0 {
        add(findings, page_path, html, sources[0].start, "sources has no entries");
    }
}

// ---- deep dives --------------------------------------------------------------------------------

// A deep dive lives at lessons/<track>/deep-dives/<slug>.html.
is_deep_dive :: (page_path: string) -> bool {
    return contains(page_path, "/deep-dives/");
}

// lessons/<track>/NN-<slug>.html: the pages the index lists and the concept map reads.
is_lesson_page :: (path: string) -> bool {
    segments := split(path, "/");
    if segments.count != 3 || segments[0] != "lessons"  return false;
    file := segments[2];
    return file.count >= 3 && is_digit_char(file[0]) && is_digit_char(file[1]) && file[2] == #char "-";
}

// The lighter contract: an article with its track and lesson, a crumb back to the lesson, one h1,
// and the shared rules. No outcomes, steps, spine, noscript, exercise link or next link.
check_deep_dive :: (html: string, page_path: string, root: string) -> [..] Finding {
    findings: [..] Finding;

    // article
    articles := collect(html, "article", "deep-dive");
    if articles.count == 0 {
        add(*findings, page_path, html, 0, "no <article class=\"deep-dive\">");
    } else {
        if articles.count > 1  add(*findings, page_path, html, articles[1].start, "more than one <article class=\"deep-dive\">");
        a := articles[0];
        _, has_track  := attr(a, "data-track");
        _, has_lesson := attr(a, "data-lesson");
        if !has_track   add(*findings, page_path, html, a.start, "deep-dive lacks data-track");
        if !has_lesson  add(*findings, page_path, html, a.start, "deep-dive lacks data-lesson");
    }

    // crumbs: a link that resolves to a lesson page
    linked := false;
    crumbs := collect(html, "p", "crumbs");
    for crumbs {
        for link: collect(inner(html, it), "a", "") {
            href, has_href := attr(link, "href");
            if has_href && is_lesson_page(resolve_relative(page_path, href))  linked = true;
        }
    }
    if !linked  add(*findings, page_path, html, ifx crumbs.count then crumbs[0].start else 0, "deep dive has no crumb link to its lesson");

    // h1
    h1s := collect(html, "h1", "");
    if h1s.count == 0      add(*findings, page_path, html, 0, "deep dive has no h1");
    else if h1s.count > 1  add(*findings, page_path, html, h1s[1].start, "deep dive has more than one h1");

    check_snippets(html, page_path, root, *findings);
    check_sidebars(html, page_path, *findings);
    check_endnotes(html, page_path, *findings);
    check_sources(html, page_path, *findings);
    for check_links(html, page_path, root)  array_add(*findings, it);

    return findings;
}

// Every relative href/src resolves to a file; every #fragment resolves to an id in the page.
check_links :: (html: string, page_path: string, root: string) -> [..] Finding {
    findings: [..] Finding;

    ids: [..] string;
    at := 0;
    while true {
        tag, found := next_tag(html, at);
        if !found  break;
        at = tag.end;
        id, has_id := attr(tag, "id");
        if has_id  array_add(*ids, id);
    }

    at = 0;
    while true {
        tag, found := next_tag(html, at);
        if !found  break;
        at = tag.end;

        attribute := "";
        if tag.name == {
          case "a";      attribute = "href";
          case "link";   attribute = "href";
          case "script"; attribute = "src";
          case "img";    attribute = "src";
          case;          continue;
        }
        target, has_target := attr(tag, attribute);
        if !has_target || target.count == 0  continue;
        if begins_with(target, "http://") || begins_with(target, "https://") || begins_with(target, "mailto:")
        || begins_with(target, "data:")   || begins_with(target, "javascript:")  continue;

        if target[0] == #char "#" {
            if target.count == 1  continue;
            fragment := slice(target, 1, target.count - 1);
            if !array_find(ids, fragment)  array_add(*findings, .{page_path, line_of(html, tag.start), tprint("no element with id '%'", fragment)});
            continue;
        }

        path := target;
        hash := find_index_from_left(path, #char "#");
        if hash >= 0  path = slice(path, 0, hash);
        query := find_index_from_left(path, #char "?");
        if query >= 0  path = slice(path, 0, query);
        if !file_exists(tprint("%1%2", root, resolve_relative(page_path, path))) {
            array_add(*findings, .{page_path, line_of(html, tag.start), tprint("link target does not exist: %", target)});
        }
    }
    return findings;
}

// The landing page: every lesson page under a track directory is linked, each track's rows run
// 0..N in order, a row that says its lesson is done links a page, the three tracks come in
// order, and links resolve.
check_index :: (html: string, root: string, pages: [] string) -> [..] Finding {
    PATH :: "index.html";
    findings: [..] Finding;

    hrefs: [..] string;
    at := 0;
    while true {
        tag, found := next_tag(html, at);
        if !found  break;
        at = tag.end;
        if tag.name != "a"  continue;
        href, has_href := attr(tag, "href");
        if has_href  array_add(*hrefs, resolve_relative(PATH, href));
    }
    for page: pages {
        if ends_with(page, "/_template.html")  continue;
        if is_deep_dive(page)                  continue;   // linked from their lesson, not the index
        if split(page, "/").count < 3          continue;   // only lessons/<track>/<file> pages must be listed
        if !array_find(hrefs, page)  array_add(*findings, .{PATH, 0, tprint("lesson page not linked from index: %", page)});
    }

    tracks := collect(html, "article", "track");
    names: [..] string;
    for tracks {
        name, _ := attr(it, "data-track");
        array_add(*names, name);
    }
    if !(names.count == 3 && names[0] == "vulkan" && names[1] == "directx" && names[2] == "metal") {
        start := ifx tracks.count > 0 then tracks[0].start else 0;
        array_add(*findings, .{PATH, line_of(html, start), tprint("tracks are [%], want vulkan, directx, metal", join(..names, separator = ", "))});
    }

    for track: tracks {
        name, _ := attr(track, "data-track");
        body := inner(html, track);
        base := body.data - html.data;   // offsets inside body, as offsets inside html
        numbers: [..] string;
        in_order := true;
        for row: collect(body, "div", "lrow") {
            n, has_n := attr(row, "data-number");
            if !has_n  continue;   // a project row
            value, parsed, remainder := string_to_int(n);
            if !(parsed && remainder.count == 0 && value == numbers.count)  in_order = false;
            array_add(*numbers, n);

            row_body := inner(body, row);
            done := false;
            for mark: collect(row_body, "span", "mark") {
                state, _ := attr(mark, "data-state");
                if state == "done" && trim(inner(row_body, mark)) == "lesson"  done = true;
            }
            if done && collect(row_body, "a", "").count == 0 {
                array_add(*findings, .{PATH, line_of(html, base + row.start), tprint("row % says the lesson is done but links nothing", n)});
            }
        }
        if !in_order {
            array_add(*findings, .{PATH, line_of(html, track.start), tprint("track '%' rows are [%], want 0..% in order", name, join(..numbers, separator = ", "), numbers.count - 1)});
        }
    }

    for check_links(html, PATH, root)  array_add(*findings, it);
    return findings;
}

// Pages run from file://, so the script may not load anything.
check_js :: (js: string, path: string) -> [..] Finding {
    findings: [..] Finding;
    for string.["fetch(", "XMLHttpRequest"] {
        at := find_index_from_left(js, it);
        if at >= 0  array_add(*findings, .{path, line_of(js, at), tprint("% must not be used: pages run from file://", it)});
    }
    return findings;
}

// ("lessons/vulkan/03.html", "../assets/x.css") -> "lessons/assets/x.css"
resolve_relative :: (page_path: string, href: string) -> string {
    dir := "";
    last_slash := find_index_from_right(page_path, #char "/");
    if last_slash >= 0  dir = slice(page_path, 0, last_slash);

    segments: [..] string;
    for split(dir, "/")   if it.count  array_add(*segments, it);
    for split(href, "/") {
        if it == "" || it == "."  continue;
        if it == ".." {
            if segments.count  pop(*segments);
            continue;
        }
        array_add(*segments, it);
    }
    return join(..segments, separator = "/");
}

// 1-based line of a byte offset.
line_of :: (text: string, offset: int) -> int {
    line := 1;
    for i: 0..min(offset, text.count) - 1  if text[i] == #char "\n"  line += 1;
    return line;
}

// Every lessons/**/*.html except lessons/assets/** and concept-map.html, sorted, relative to root.
lesson_pages :: (root: string) -> [..] string {
    pages: [..] string;
    dir := tprint("%lessons", root);
    if !file_exists(dir)  return pages;
    for file_list(dir, recursive = true) {
        if !ends_with(it, ".html")  continue;
        rel := slice(it, root.count, it.count - root.count);
        if begins_with(rel, "lessons/assets/")   continue;
        if ends_with(rel, "/concept-map.html")   continue;
        array_add(*pages, copy_string(rel));
    }
    quick_sort(pages, compare_strings);
    return pages;
}

// Everything check-lessons looks at. pages counts the HTML pages checked.
check_all :: (root: string) -> (findings: [..] Finding, pages: int) {
    findings: [..] Finding;
    pages := lesson_pages(root);
    for page: pages {
        html, ok := read_entire_file(tprint("%1%2", root, page), log_errors = false);
        if !ok {
            array_add(*findings, .{page, 0, "could not read the page"});
            continue;
        }
        if is_deep_dive(page)  for check_deep_dive(html, page, root)  array_add(*findings, it);
        else                   for check_lesson(html, page, root)     array_add(*findings, it);
    }

    count := pages.count;

    INDEX :: "index.html";
    index_html, has_index := read_entire_file(tprint("%1%2", root, INDEX), log_errors = false);
    if has_index {
        for check_index(index_html, root, pages)  array_add(*findings, it);
        count += 1;
    } else {
        array_add(*findings, .{INDEX, 0, "index.html is missing"});
    }

    MAP :: "lessons/concept-map.html";
    committed, has_map := read_entire_file(tprint("%1%2", root, MAP), log_errors = false);
    if !has_map {
        array_add(*findings, .{MAP, 0, "lessons/concept-map.html is missing: run first.jai - concept-map"});
    } else {
        if committed != concept_map_html(collect_sidebars(root)) {
            array_add(*findings, .{MAP, 0, "lessons/concept-map.html is stale: run first.jai - concept-map"});
        } else {
            for check_links(committed, MAP, root)  array_add(*findings, it);
        }
        count += 1;
    }

    SPINE :: "lessons/assets/spine.js";
    js, ok := read_entire_file(tprint("%1%2", root, SPINE), log_errors = false);
    if ok  for check_js(js, SPINE)  array_add(*findings, it);

    return findings, count;
}

// ---- the concept map -----------------------------------------------------------------------------

// One sidebar from one lesson page: the Vulkan term, the lesson, and what the other APIs call it.
Sidebar_Entry :: struct {
    term:         string;
    track:        string;
    number:       string;
    lesson_title: string;
    href:         string;   // "vulkan/03-shaders.html#sb-clear", relative to lessons/
    d3d12:        string;   // the dd after the "D3D12" dt, or ""
    metal:        string;   // the dd after the "Metal" dt, or ""
}

// Every sidebar in every lessons/<track>/NN-*.html, sorted by term (case-insensitively), then
// track, then lesson number. The template and anything outside a track directory are never read.
collect_sidebars :: (root: string) -> [..] Sidebar_Entry {
    entries: [..] Sidebar_Entry;
    for page: lesson_pages(root) {
        if !is_lesson_page(page)  continue;
        segments := split(page, "/");
        file := segments[2];

        html, ok := read_entire_file(tprint("%1%2", root, page), log_errors = false);
        if !ok {
            log_error("concept-map: could not read %; its sidebars are missing from the map", page);
            continue;
        }

        track := "";
        number := "";
        title := "";
        articles := collect(html, "article", "lesson");
        if articles.count {
            t, _  := attr(articles[0], "data-track");
            n, _  := attr(articles[0], "data-number");
            track  = t;
            number = n;
        }
        h1s := collect(html, "h1", "");
        if h1s.count  title = trim(inner(html, h1s[0]));

        for sb: collect(html, "aside", "sidebar") {
            e: Sidebar_Entry;
            term, _ := attr(sb, "data-term");
            id, _   := attr(sb, "id");
            e.term         = term;
            e.track        = track;
            e.number       = number;
            e.lesson_title = title;
            e.href         = tprint("%1/%2#%3", segments[1], file, id);

            body := inner(html, sb);
            dls  := collect(body, "dl", "elsewhere");
            if dls.count {
                pairs := inner(body, dls[0]);
                api := "";
                at := 0;
                while true {
                    tag, found := next_tag(pairs, at);
                    if !found  break;
                    at = tag.end;
                    if tag.name == "dt" {
                        api = trim(inner(pairs, tag));
                    } else if tag.name == "dd" {
                        text := trim(inner(pairs, tag));
                        if api == "D3D12"       e.d3d12 = text;
                        else if api == "Metal"  e.metal = text;
                    }
                }
            }
            array_add(*entries, e);
        }
    }
    quick_sort(entries, compare_entries);
    return entries;
}

compare_entries :: (a: Sidebar_Entry, b: Sidebar_Entry) -> int {
    c := compare_strings(to_lower_copy(a.term), to_lower_copy(b.term));
    if c != 0  return c;
    c = compare_strings(a.track, b.track);
    if c != 0  return c;
    na, _ := string_to_int(a.number);
    nb, _ := string_to_int(b.number);
    if na < nb  return -1;
    if na > nb  return 1;
    return 0;
}

// The whole concept-map page. Deterministic, so check_all can compare it with the committed file.
concept_map_html :: (entries: [] Sidebar_Entry) -> string {
    b: String_Builder;
    append(*b, CONCEPT_MAP_HEAD);
    if entries.count == 0 {
        append(*b, "<p class=\"empty\">No sidebars yet.</p>\n");
    } else {
        append(*b, "<table class=\"concept-map\">\n<thead><tr><th>Term</th><th>Lesson</th><th>D3D12</th><th>Metal</th></tr></thead>\n<tbody>\n");
        for entries {
            print_to_builder(*b, "<tr><td>%1</td><td><a href=\"%2\">%3 %4: %5</a></td><td>%6</td><td>%7</td></tr>\n",
                             it.term, it.href, it.track, it.number, it.lesson_title, cell(it.d3d12), cell(it.metal));
        }
        append(*b, "</tbody>\n</table>\n");
    }
    append(*b, CONCEPT_MAP_FOOT);
    return builder_to_string(*b);
}

cell :: (s: string) -> string { return ifx s.count then s else "—"; }

CONCEPT_MAP_HEAD :: #string HTML
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Concept map</title>
<link rel="stylesheet" href="assets/lesson.css">
</head>
<body>
<main class="page">
<p class="crumbs"><a href="../index.html">Understanding Graphics APIs</a> · Concept map</p>
<h1>Concept map</h1>
<p class="lead">The cross-API glossary, assembled by <code>first.jai - concept-map</code> from every sidebar in every
lesson: the Vulkan term, the lesson that introduces it, and what D3D12 and Metal call it. Generated;
edit the sidebar, not this page.</p>
HTML

CONCEPT_MAP_FOOT :: #string HTML
</main>
</body>
</html>
HTML

// ---- the tag scanner ---------------------------------------------------------------------------

Tag :: struct {
    name:  string;   // as written; authored pages use lowercase
    attrs: string;   // raw text between the name and the closing '>'
    start: int;      // offset of '<'
    end:   int;      // offset just past '>'
}

// The next open tag at or after `from`: closing tags, comments, doctype and processing
// instructions are skipped.
next_tag :: (html: string, from: int) -> (tag: Tag, found: bool) {
    i := from;
    while i < html.count {
        lt := find_index_from_left(html, #char "<", i);
        if lt < 0  break;

        rest := slice(html, lt, html.count - lt);
        if begins_with(rest, "<!--") {
            close := find_index_from_left(html, "-->", lt + 4);
            if close < 0  break;
            i = close + 3;
            continue;
        }

        j := lt + 1;
        if j >= html.count  break;
        if html[j] == #char "/" || html[j] == #char "!" || html[j] == #char "?" {
            i = j;
            continue;
        }

        k := j;
        while k < html.count && is_name_char(html[k])  k += 1;
        if k == j {
            i = j;
            continue;
        }
        gt := find_index_from_left(html, #char ">", k);
        if gt < 0  break;

        tag: Tag;
        tag.name  = slice(html, j, k - j);
        tag.attrs = slice(html, k, gt - k);
        tag.start = lt;
        tag.end   = gt + 1;
        return tag, true;
    }
    return .{}, false;
}

// Every open tag named `name`; with a non-empty `class`, only those carrying that class token.
collect :: (html: string, name: string, class: string) -> [..] Tag {
    tags: [..] Tag;
    at := 0;
    while true {
        tag, found := next_tag(html, at);
        if !found  break;
        at = tag.end;
        if tag.name != name  continue;
        if class.count && !has_class(tag, class)  continue;
        array_add(*tags, tag);
    }
    return tags;
}

Attr :: struct { name: string; value: string; has_value: bool; }

attributes :: (tag: Tag) -> [..] Attr {
    result: [..] Attr;
    s := tag.attrs;
    i := 0;
    while i < s.count {
        while i < s.count && is_ws(s[i])  i += 1;
        if i >= s.count  break;
        if s[i] == #char "/" {   // a self-closing slash
            i += 1;
            continue;
        }
        ns := i;
        while i < s.count && !is_ws(s[i]) && s[i] != #char "="  i += 1;
        a: Attr;
        a.name = slice(s, ns, i - ns);
        if i < s.count && s[i] == #char "=" {
            i += 1;
            if i < s.count && (s[i] == #char "\"" || s[i] == #char "'") {
                q := s[i];
                i += 1;
                vs := i;
                while i < s.count && s[i] != q  i += 1;
                a.value = slice(s, vs, i - vs);
                if i < s.count  i += 1;
            } else {
                vs := i;
                while i < s.count && !is_ws(s[i])  i += 1;
                a.value = slice(s, vs, i - vs);
            }
            a.has_value = true;
        }
        array_add(*result, a);
    }
    return result;
}

// The attribute's value; found is true for a boolean attribute too (value "").
attr :: (tag: Tag, name: string) -> (value: string, found: bool) {
    for attributes(tag)  if it.name == name  return it.value, true;
    return "", false;
}

has_class :: (tag: Tag, name: string) -> bool {
    value, found := attr(tag, "class");
    if !found  return false;
    for split(value, " ")  if trim(it) == name  return true;
    return false;
}

// The text between the open tag and its matching closing tag; nested tags of the same name are
// skipped over (a div inside a div), other names are not tracked; to the end if unclosed.
inner :: (html: string, tag: Tag) -> string {
    close_token := tprint("</%>", tag.name);
    depth := 0;
    at := tag.end;
    while true {
        close := find_index_from_left(html, close_token, at);
        if close < 0  return slice(html, tag.end, html.count - tag.end);

        scan := at;   // same-named opens between here and that close each need a close of their own
        while true {
            t, found := next_tag(html, scan);
            if !found || t.start >= close  break;
            scan = t.end;
            if t.name == tag.name  depth += 1;
        }
        if depth == 0  return slice(html, tag.end, close - tag.end);
        depth -= 1;
        at = close + close_token.count;
    }
    return "";   // unreachable; the compiler does not treat `while true` as non-terminating
}

count_lines :: (text: string) -> int {
    if text.count == 0  return 0;
    n := 0;
    for i: 0..text.count - 1  if text[i] == #char "\n"  n += 1;
    if text[text.count - 1] != #char "\n"  n += 1;
    return n;
}

is_ws         :: (c: u8) -> bool { return c == #char " " || c == #char "\t" || c == #char "\n" || c == #char "\r"; }
is_digit_char :: (c: u8) -> bool { return c >= #char "0" && c <= #char "9"; }
is_name_char :: (c: u8) -> bool { return (c >= #char "a" && c <= #char "z") || (c >= #char "A" && c <= #char "Z") || (c >= #char "0" && c <= #char "9") || c == #char "-"; }
