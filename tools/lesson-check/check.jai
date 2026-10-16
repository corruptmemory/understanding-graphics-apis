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

check_lesson :: (html: string, page_path: string, root: string) -> [..] Finding {
    findings: [..] Finding;
    add :: (findings: *[..] Finding, page_path: string, html: string, offset: int, message: string) {
        array_add(findings, .{page_path, line_of(html, offset), message});
    }

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

    // snippets
    for collect(html, "pre", "snippet") {
        src, has_src     := attr(it, "data-src");
        _,   illustrative := attr(it, "data-illustrative");
        if illustrative && has_src {
            add(*findings, page_path, html, it.start, "illustrative snippet carries data-src");
        } else if !illustrative && !has_src {
            add(*findings, page_path, html, it.start, "snippet has neither data-src nor data-illustrative");
        } else if has_src {
            colon := find_index_from_right(src, #char ":");
            line_text := ifx colon >= 0 then slice(src, colon + 1, src.count - colon - 1) else "";
            line, parsed, remainder := string_to_int(line_text);
            if colon < 0 || !parsed || remainder.count > 0 {
                add(*findings, page_path, html, it.start, tprint("snippet '%': data-src must be path:line", src));
                continue;
            }
            file := tprint("%1%2", root, slice(src, 0, colon));
            if !file_exists(file) {
                add(*findings, page_path, html, it.start, tprint("snippet '%': no such file", src));
                continue;
            }
            text, ok := read_entire_file(file, log_errors = false);
            if !ok {
                add(*findings, page_path, html, it.start, tprint("snippet '%': could not read the file", src));
                continue;
            }
            if line < 1 || line > count_lines(text)  add(*findings, page_path, html, it.start, tprint("snippet '%': line is past the end", src));
        }
    }

    // sidebars
    for collect(html, "aside", "sidebar") {
        _, has_id   := attr(it, "id");
        _, has_term := attr(it, "data-term");
        if !has_id    add(*findings, page_path, html, it.start, "sidebar lacks id");
        if !has_term  add(*findings, page_path, html, it.start, "sidebar lacks data-term");
        body := inner(html, it);
        dls := collect(body, "dl", "elsewhere");
        if dls.count == 0 {
            add(*findings, page_path, html, it.start, "sidebar has no dl.elsewhere");
        } else {
            pairs := inner(body, dls[0]);
            if collect(pairs, "dt", "").count == 0 || collect(pairs, "dd", "").count == 0 {
                add(*findings, page_path, html, it.start, "sidebar's dl.elsewhere has no dt/dd pair");
            }
        }
    }

    // endnotes
    endnotes := collect(html, "details", "endnote");
    if endnotes.count > 3  add(*findings, page_path, html, endnotes[3].start, tprint("% endnotes, at most 3", endnotes.count));
    for endnotes {
        _, open := attr(it, "open");
        if open  add(*findings, page_path, html, it.start, "endnote is open by default");
        if collect(inner(html, it), "summary", "").count == 0  add(*findings, page_path, html, it.start, "endnote has no summary");
    }

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

    // sources
    sources := collect(html, "section", "sources");
    if sources.count == 0 {
        add(*findings, page_path, html, 0, "no sources section");
    } else if collect(inner(html, sources[0]), "li", "").count == 0 {
        add(*findings, page_path, html, sources[0].start, "sources has no entries");
    }

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
    for pages {
        html, ok := read_entire_file(tprint("%1%2", root, it), log_errors = false);
        if !ok {
            array_add(*findings, .{it, 0, "could not read the page"});
            continue;
        }
        for check_lesson(html, it, root)  array_add(*findings, it);
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

    SPINE :: "lessons/assets/spine.js";
    js, ok := read_entire_file(tprint("%1%2", root, SPINE), log_errors = false);
    if ok  for check_js(js, SPINE)  array_add(*findings, it);

    return findings, count;
}

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

is_ws        :: (c: u8) -> bool { return c == #char " " || c == #char "\t" || c == #char "\n" || c == #char "\r"; }
is_name_char :: (c: u8) -> bool { return (c >= #char "a" && c <= #char "z") || (c >= #char "A" && c <= #char "Z") || (c >= #char "0" && c <= #char "9") || c == #char "-"; }
