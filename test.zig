// test.zig -lc -Isrc -Ihtml --verbose-cimport -cflags -fno-sanitize=undefined -- src/*.c html/*.c

const std = @import("std");
usingnamespace @import("html_entities.zig");

const c = @cImport({
    @cInclude("markdown.h");
    @cInclude("html.h");
    @cInclude("autolink.h");
});

// zig fmt: off
const snudown_default_render_flags = 0
    | c.HTML_SKIP_HTML
    | c.HTML_SKIP_IMAGES
    | c.HTML_SAFELINK
    | c.HTML_ESCAPE
    | c.HTML_USE_XHTML
;

const snudown_default_md_flags = 0
    | c.MKDEXT_NO_INTRA_EMPHASIS
    | c.MKDEXT_SUPERSCRIPT
    | c.MKDEXT_AUTOLINK
    | c.MKDEXT_STRIKETHROUGH
    | c.MKDEXT_TABLES
;
// zig fmt: on

fn snudown_link_attr(ob: [*c]c.struct_buf, link: [*c]const c.struct_buf, opaquev: ?*c_void) callconv(.C) void {
    // const literal = " rel=\"noreferrer noopener\"";
    // c.bufput(ob, literal, literal.len);
}

pub var html_element_whitelist = &[_]?[*c]const u8{ "tr", "th", "td", "table", "tbody", "thead", "tfoot", "caption", null };
pub var html_attr_whitelist = &[_]?[*c]const u8{ "colspan", "rowspan", "cellspacing", "cellpadding", "scope", null };

fn parse(alloc: *std.mem.Allocator, inmd: []const u8) []u8 {
    var callbacks: c.struct_sd_callbacks = undefined;
    var options: c.struct_html_renderopt = undefined;
    c.sdhtml_renderer(
        &callbacks,
        &options,
        snudown_default_render_flags,
    );

    options.link_attributes = snudown_link_attr;
    options.html_element_whitelist = @intToPtr([*c][*c]u8, @ptrToInt(html_element_whitelist));
    options.html_attr_whitelist = @intToPtr([*c][*c]u8, @ptrToInt(html_attr_whitelist));

    const parser = c.sd_markdown_new(snudown_default_md_flags, 16, 64, &callbacks, &options);

    const ob: *c.struct_buf = c.bufnew(128);
    defer c.bufrelease(ob);

    c.sd_markdown_render(ob, inmd.ptr, inmd.len, parser);

    return alloc.dupe(u8, if (ob.size == 0) "" else ob.data[0..ob.size]) catch @panic("oom");
}

export fn markdownToHTML(markdown: [*]u8, markdown_len: usize, out_len: *usize) [*]u8 {
    const alloc = std.heap.page_allocator;
    const ob = parse(alloc, markdown[0..markdown_len]);
    return ob.ptr;
}

export fn freeText(ptr: [*]u8, len: usize) void {
    std.heap.page_allocator.free(ptr[0..len]);
}

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    const ob = parse(alloc, "Test!");
    defer alloc.free(ob);
    std.debug.warn("res: {s}", .{ob});
}

test "post markdown" {
    const alloc = std.testing.allocator;
    inline for (.{
        .{ "", "" },
        .{ "http://www.reddit.com", "<p><a href=\"http://www.reddit.com\">http://www.reddit.com</a></p>\n" },
        .{ "http://www.reddit.com/a\x00b", "<p><a href=\"http://www.reddit.com/ab\">http://www.reddit.com/ab</a></p>\n" },
        .{ "foo@example.com", "<p><a href=\"mailto:foo@example.com\">foo@example.com</a></p>\n" },
        .{ "[foo](http://en.wikipedia.org/wiki/Link_(film\\))", "<p><a href=\"http://en.wikipedia.org/wiki/Link_(film)\">foo</a></p>\n" },
        .{ "(http://tsfr.org)", "<p>(<a href=\"http://tsfr.org\">http://tsfr.org</a>)</p>\n" },
        .{ "[A link with a /r/subreddit in it](/lol)", "<p><a href=\"/lol\">A link with a /r/subreddit in it</a></p>\n" },
        .{ "[A link with a http://www.url.com in it](/lol)", "<p><a href=\"/lol\">A link with a http://www.url.com in it</a></p>\n" },
        .{ "[Empty Link]()", "<p>[Empty Link]()</p>\n" },
        .{ "http://en.wikipedia.org/wiki/café_racer", "<p><a href=\"http://en.wikipedia.org/wiki/caf%C3%A9_racer\">http://en.wikipedia.org/wiki/café_racer</a></p>\n" },
        .{ "#####################################################hi", "<h6>###############################################hi</h6>\n" },
        .{ "[foo](http://bar\nbar)", "<p><a href=\"http://bar%0Abar\">foo</a></p>\n" },
        .{ "/r/test", "<p><a href=\"/r/test\">/r/test</a></p>\n" },
        .{ "Words words /r/test words", "<p>Words words <a href=\"/r/test\">/r/test</a> words</p>\n" },
        .{ "/r/", "<p>/r/</p>\n" },
        .{ "escaped \\/r/test", "<p>escaped /r/test</p>\n" },
        .{ "ampersands http://www.google.com?test&blah", "<p>ampersands <a href=\"http://www.google.com?test&amp;blah\">http://www.google.com?test&amp;blah</a></p>\n" },
        .{ "[_regular_ link with nesting](/test)", "<p><a href=\"/test\"><em>regular</em> link with nesting</a></p>\n" },
        .{ " www.a.co?with&test", "<p><a href=\"http://www.a.co?with&amp;test\">www.a.co?with&amp;test</a></p>\n" },
        .{ "Normal^superscript", "<p>Normal<sup>superscript</sup></p>\n" },
        .{ "Escape\\^superscript", "<p>Escape^superscript</p>\n" },
        .{ "~~normal strikethrough~~", "<p><del>normal strikethrough</del></p>\n" },
        .{ "\\~~escaped strikethrough~~", "<p>~~escaped strikethrough~~</p>\n" },
        .{ "anywhere\x03, you", "<p>anywhere, you</p>\n" },
        .{ "[Test](//test)", "<p><a href=\"//test\">Test</a></p>\n" },
        .{ "[Test](//#test)", "<p><a href=\"//#test\">Test</a></p>\n" },
        .{ "[Test](#test)", "<p><a href=\"#test\">Test</a></p>\n" },
        .{ "[Test](git://github.com)", "<p><a href=\"git://github.com\">Test</a></p>\n" },
        .{ "[Speculation](//?)", "<p><a href=\"//?\">Speculation</a></p>\n" },
        .{ "/r/sr_with_underscores", "<p><a href=\"/r/sr_with_underscores\">/r/sr_with_underscores</a></p>\n" },
        .{ "[Test](///#test)", "<p><a href=\"///#test\">Test</a></p>\n" },
        .{ "/r/multireddit+test+yay", "<p><a href=\"/r/multireddit+test+yay\">/r/multireddit+test+yay</a></p>\n" },
        .{ "<test>", "<p>&lt;test&gt;</p>\n" },
        .{ "words_with_underscores", "<p>words_with_underscores</p>\n" },
        .{ "words*with*asterisks", "<p>words<em>with</em>asterisks</p>\n" },
        .{ "~test", "<p>~test</p>\n" },
        .{ "/u/test", "<p><a href=\"/u/test\">/u/test</a></p>\n" },
        .{ "/u/test/m/test test", "<p><a href=\"/u/test/m/test\">/u/test/m/test</a> test</p>\n" },
        .{ "/U/nope", "<p>/U/nope</p>\n" },
        .{ "/r/test/m/test test", "<p><a href=\"/r/test/m/test\">/r/test/m/test</a> test</p>\n" },
        .{ "/r/test/w/test test", "<p><a href=\"/r/test/w/test\">/r/test/w/test</a> test</p>\n" },
        .{ "/r/test/comments/test test", "<p><a href=\"/r/test/comments/test\">/r/test/comments/test</a> test</p>\n" },
        .{ "/u/test/commentscommentscommentscommentscommentscommentscomments/test test", "<p><a href=\"/u/test/commentscommentscommentscommentscommentscommentscomments/test\">/u/test/commentscommentscommentscommentscommentscommentscomments/test</a> test</p>\n" },
        .{ "a /u/reddit", "<p>a <a href=\"/u/reddit\">/u/reddit</a></p>\n" },
        .{ "u/reddit", "<p><a href=\"/u/reddit\">u/reddit</a></p>\n" },
        .{ "a u/reddit", "<p>a <a href=\"/u/reddit\">u/reddit</a></p>\n" },
        .{ "a u/reddit/foobaz", "<p>a <a href=\"/u/reddit/foobaz\">u/reddit/foobaz</a></p>\n" },
        .{ "foo:u/reddit", "<p>foo:<a href=\"/u/reddit\">u/reddit</a></p>\n" },
        .{ "fuu/reddit", "<p>fuu/reddit</p>\n" },
        .{ "a\u{3002}u/reddit", "<p>a\u{3002}u/reddit</p>\n" },
        .{ "\\/u/me", "<p>/u/me</p>\n" },
        .{ "\\\\/u/me", "<p>\\<a href=\"/u/me\">/u/me</a></p>\n" },
        .{ "\\u/me", "<p>\\<a href=\"/u/me\">u/me</a></p>\n" },
        .{ "\\\\u/me", "<p>\\<a href=\"/u/me\">u/me</a></p>\n" },
        .{ "u\\/me", "<p>u/me</p>\n" },
        .{ "*u/me*", "<p><em><a href=\"/u/me\">u/me</a></em></p>\n" },
        .{ "foo^u/me", "<p>foo<sup><a href=\"/u/me\">u/me</a></sup></p>\n" },
        .{ "*foo*u/me", "<p><em>foo</em><a href=\"/u/me\">u/me</a></p>\n" },
        .{ "u/me", "<p><a href=\"/u/me\">u/me</a></p>\n" },
        .{ "/u/me", "<p><a href=\"/u/me\">/u/me</a></p>\n" },
        .{ "u/m", "<p>u/m</p>\n" },
        .{ "/u/m", "<p>/u/m</p>\n" },
        .{ "/f/oobar", "<p>/f/oobar</p>\n" },
        .{ "f/oobar", "<p>f/oobar</p>\n" },
        .{ "/r/test/commentscommentscommentscommentscommentscommentscomments/test test", "<p><a href=\"/r/test/commentscommentscommentscommentscommentscommentscomments/test\">/r/test/commentscommentscommentscommentscommentscommentscomments/test</a> test</p>\n" },
        .{ "blah \\", "<p>blah \\</p>\n" },
        .{ "/r/whatever: fork", "<p><a href=\"/r/whatever\">/r/whatever</a>: fork</p>\n" },
        .{ "/r/t:timereddit", "<p><a href=\"/r/t:timereddit\">/r/t:timereddit</a></p>\n" },
        .{ "/r/reddit.com", "<p><a href=\"/r/reddit.com\">/r/reddit.com</a></p>\n" },
        .{ "/r/not.cool", "<p><a href=\"/r/not\">/r/not</a>.cool</p>\n" },
        .{ "/r/very+clever+multireddit+reddit.com+t:fork+yay", "<p><a href=\"/r/very+clever+multireddit+reddit.com+t:fork+yay\">/r/very+clever+multireddit+reddit.com+t:fork+yay</a></p>\n" },
        .{ "/r/t:heatdeathoftheuniverse", "<p><a href=\"/r/t:heatdeathoftheuniverse\">/r/t:heatdeathoftheuniverse</a></p>\n" },
        .{ "/r/all-minus-something", "<p><a href=\"/r/all-minus-something\">/r/all-minus-something</a></p>\n" },
        .{ "/r/notall-minus", "<p><a href=\"/r/notall\">/r/notall</a>-minus</p>\n" },
        .{ "a /r/reddit.com", "<p>a <a href=\"/r/reddit.com\">/r/reddit.com</a></p>\n" },
        .{ "a r/reddit.com", "<p>a <a href=\"/r/reddit.com\">r/reddit.com</a></p>\n" },
        .{ "foo:r/reddit.com", "<p>foo:<a href=\"/r/reddit.com\">r/reddit.com</a></p>\n" },
        .{ "foobar/reddit.com", "<p>foobar/reddit.com</p>\n" },
        .{ "a\u{3002}r/reddit.com", "<p>a\u{3002}r/reddit.com</p>\n" },
        .{ "/R/reddit.com", "<p>/R/reddit.com</p>\n" },
        .{ "/r/irc://foo.bar/", "<p><a href=\"/r/irc\">/r/irc</a>://foo.bar/</p>\n" },
        .{ "/r/t:irc//foo.bar/", "<p><a href=\"/r/t:irc//foo\">/r/t:irc//foo</a>.bar/</p>\n" },
        .{ "/r/all-irc://foo.bar/", "<p><a href=\"/r/all-irc\">/r/all-irc</a>://foo.bar/</p>\n" },
        .{ "/r/foo+irc://foo.bar/", "<p><a href=\"/r/foo+irc\">/r/foo+irc</a>://foo.bar/</p>\n" },
        .{ "/r/www.example.com", "<p><a href=\"/r/www\">/r/www</a>.example.com</p>\n" },
        .{ ".http://reddit.com", "<p>.<a href=\"http://reddit.com\">http://reddit.com</a></p>\n" },
        .{ "[r://<http://reddit.com/>](/aa)", "<p><a href=\"/aa\">r://<a href=\"http://reddit.com/\">http://reddit.com/</a></a></p>\n" },
        .{ "/u/http://www.reddit.com/user/reddit", "<p><a href=\"/u/http\">/u/http</a>://<a href=\"http://www.reddit.com/user/reddit\">www.reddit.com/user/reddit</a></p>\n" },
        .{ "www.http://example.com/", "<p><a href=\"http://www.http://example.com/\">www.http://example.com/</a></p>\n" },
        .{ "|||||\n-|-|-|-|-|\n|\n", "<table><thead>\n<tr>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n</tr>\n</thead><tbody>\n<tr>\n<td colspan=\"4\" ></td>\n</tr>\n</tbody></table>\n" },
        .{ "||\n-|-|\n|\n", "<table><thead>\n<tr>\n<th></th>\n</tr>\n</thead><tbody>\n<tr>\n<td></td>\n</tr>\n</tbody></table>\n" },
        .{ "|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||\n-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|\n|\n", "<table><thead>\n<tr>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n<th></th>\n</tr>\n</thead><tbody>\n<tr>\n<td colspan=\"64\" ></td>\n</tr>\n</tbody></table>\n" },
        .{ "||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||\n-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|\n|\n", "<p>||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||\n-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|-|\n|</p>\n" },
        .{ "&thetasym;", "<p>&thetasym;</p>\n" },
        .{ "&foobar;", "<p>&amp;foobar;</p>\n" },
        .{ "&nbsp", "<p>&amp;nbsp</p>\n" },
        .{ "&#foobar;", "<p>&amp;#foobar;</p>\n" },
        .{ "&#xfoobar;", "<p>&amp;#xfoobar;</p>\n" },
        .{ "&#9999999999;", "<p>&amp;#9999999999;</p>\n" },
        .{ "&#99;", "<p>&#99;</p>\n" },
        .{ "&#x7E;", "<p>&#x7E;</p>\n" },
        .{ "&#X7E;", "<p>&#x7E;</p>\n" },
        .{ "&frac12;", "<p>&frac12;</p>\n" },
        .{ "aaa&frac12;aaa", "<p>aaa&frac12;aaa</p>\n" },
        .{ "&", "<p>&amp;</p>\n" },
        .{ "&;", "<p>&amp;;</p>\n" },
        .{ "&#;", "<p>&amp;#;</p>\n" },
        .{ "&#x;", "<p>&amp;#x;</p>\n" },
        .{ "> quotey mcquoteface", "<blockquote>\n<p>quotey mcquoteface</p>\n</blockquote>\n" },
        .{ "> quotey mcquoteface\nnew line of text what happens?", "<blockquote>\n<p>quotey mcquoteface\nnew line of text what happens?</p>\n</blockquote>\n" },
        .{ "> quotey mcquoteface\n\ntwo new lines then text what happens?", "<blockquote>\n<p>quotey mcquoteface</p>\n</blockquote>\n\n<p>two new lines then text what happens?</p>\n" },
        .{ "> quotey mcquoteface\n> more quotey", "<blockquote>\n<p>quotey mcquoteface\nmore quotey</p>\n</blockquote>\n" },
        .{ "> quotey macquoteface\n\n> another quotey", "<blockquote>\n<p>quotey macquoteface</p>\n\n<p>another quotey</p>\n</blockquote>\n" },
        .{ ">! spoily mcspoilerface", "<blockquote class=\"md-spoiler-text\">\n<p>spoily mcspoilerface</p>\n</blockquote>\n" },
        .{ ">! spoily mcspoilerface\nmore spoilage goes here", "<blockquote class=\"md-spoiler-text\">\n<p>spoily mcspoilerface\nmore spoilage goes here</p>\n</blockquote>\n" },
        .{ ">! spoily mcspoilerface > incorrect quote syntax", "<blockquote class=\"md-spoiler-text\">\n<p>spoily mcspoilerface &gt; incorrect quote syntax</p>\n</blockquote>\n" },
        .{ ">! spoily mcspoilerface\n\n", "<blockquote class=\"md-spoiler-text\">\n<p>spoily mcspoilerface</p>\n</blockquote>\n" },
        .{ ">! spoily mcspoilerface\n\nnormal text here", "<blockquote class=\"md-spoiler-text\">\n<p>spoily mcspoilerface</p>\n</blockquote>\n\n<p>normal text here</p>\n" },
        .{ ">! spoily mcspoilerface\n>! blockspoiler continuation", "<blockquote class=\"md-spoiler-text\">\n<p>spoily mcspoilerface\nblockspoiler continuation</p>\n</blockquote>\n" },
        .{ ">! spoily mcspoilerface\n> quotey mcquoteface", "<blockquote class=\"md-spoiler-text\">\n<p>spoily mcspoilerface</p>\n\n<blockquote>\n<p>quotey mcquoteface</p>\n</blockquote>\n</blockquote>\n" },
        .{ ">! spoiler p1\n>!\n>! spoiler p2\n>! spoiler p3", "<blockquote class=\"md-spoiler-text\">\n<p>spoiler p1</p>\n\n<p>spoiler p2\nspoiler p3</p>\n</blockquote>\n" },
        .{ ">>! spoiler p1\n>!\n>! spoiler p2\n>! spoiler p3", "<blockquote>\n<blockquote class=\"md-spoiler-text\">\n<p>spoiler p1</p>\n\n<p>spoiler p2\nspoiler p3</p>\n</blockquote>\n</blockquote>\n" },
        .{ ">>! spoiler p1\n>!\n>! spoiler p2\n\nnew text", "<blockquote>\n<blockquote class=\"md-spoiler-text\">\n<p>spoiler p1</p>\n\n<p>spoiler p2</p>\n</blockquote>\n</blockquote>\n\n<p>new text</p>\n" },
        .{ ">>! spoiler p1\n>!\n>! spoiler p2\n\n>! new blockspoiler", "<blockquote>\n<blockquote class=\"md-spoiler-text\">\n<p>spoiler p1</p>\n\n<p>spoiler p2</p>\n</blockquote>\n</blockquote>\n\n<blockquote class=\"md-spoiler-text\">\n<p>new blockspoiler</p>\n</blockquote>\n" },
        .{ "! this is not a spoiler", "<p>! this is not a spoiler</p>\n" },
        .{ ">!\nTesting", "<blockquote class=\"md-spoiler-text\">\n<p>Testing</p>\n</blockquote>\n" },
        .{ ">!\n\nTesting", "<blockquote class=\"md-spoiler-text\">\n</blockquote>\n\n<p>Testing</p>\n" },
        .{ ">!", "<blockquote class=\"md-spoiler-text\">\n</blockquote>\n" },
        .{ ">!\n>!", "<blockquote class=\"md-spoiler-text\">\n</blockquote>\n" },
        .{ ">", "<blockquote>\n</blockquote>\n" },
        .{ "> some quote goes here\n>", "<blockquote>\n<p>some quote goes here</p>\n</blockquote>\n" },
        .{ "This is an >!inline spoiler!< sentence.", "<p>This is an <span class=\"md-spoiler-text\">inline spoiler</span> sentence.</p>\n" },
        .{ ">!Inline spoiler!< starting the sentence", "<p><span class=\"md-spoiler-text\">Inline spoiler</span> starting the sentence</p>\n" },
        .{ "Inline >!spoiler with *emphasis*!< test", "<p>Inline <span class=\"md-spoiler-text\">spoiler with <em>emphasis</em></span> test</p>\n" },
        .{ ">! This is an illegal blockspoiler >!with an inline spoiler!<", "<p>&gt;! This is an illegal blockspoiler <span class=\"md-spoiler-text\">with an inline spoiler</span></p>\n" },
        .{ "This is an >!inline spoiler with some >!additional!< text!<", "<p>This is an <span class=\"md-spoiler-text\">inline spoiler with some &gt;!additional</span> text!&lt;</p>\n" },
    }) |item| {
        const html = parse(alloc, item[0]);
        defer alloc.free(html);
        std.testing.expectEqualStrings(item[1], html);
    }
}
