// Colors code blocks by syntax. The plugin sees only the code of a block
// and its language: no messages, no network, no storage.

type Token = Mg.CodeToken;

interface Grammar {
  keywords: Set<string>;
  // Line comment openers, such as "//" or "#".
  line: string[];
  // Whether /* ... */ comments exist.
  block: boolean;
  // Whether a capitalized name is a type (not in shells, where it is a
  // variable or a command).
  types: boolean;
  // Whether keywords match in any case, as in SQL.
  caseless?: boolean;
}

const words = (s: string) => new Set(s.split(/\s+/).filter((w) => w.length > 0));

const literals = "true false null nil none None True False undefined NaN";

const cLike = `if else for while do switch case default break continue return
  goto struct union enum typedef sizeof static const extern void int char
  long short float double unsigned signed bool auto inline volatile register`;

const grammars: Record<string, Grammar> = {
  js: {
    keywords: words(`${literals} var let const function return if else for while
      do switch case default break continue new delete typeof instanceof in of
      class extends super this import export from as async await yield try
      catch finally throw void static get set interface type enum implements
      private public protected readonly declare namespace abstract keyof`),
    line: ["//"],
    block: true,
    types: true,
  },
  dart: {
    keywords: words(`${literals} var final const late required void dynamic
      return if else for while do switch case default break continue new class
      extends implements with mixin enum extension typedef import export
      library part show hide as is async await yield sync try catch on finally
      throw rethrow static abstract sealed base interface factory operator get
      set this super assert in external covariant`),
    line: ["//"],
    block: true,
    types: true,
  },
  python: {
    keywords: words(`${literals} def class return if elif else for while break
      continue pass import from as with try except finally raise lambda yield
      global nonlocal assert del in is not and or async await match case self`),
    line: ["#"],
    block: false,
    types: true,
  },
  go: {
    keywords: words(`${literals} package import func return if else for range
      switch case default break continue go defer select chan map struct
      interface type var const fallthrough goto iota`),
    line: ["//"],
    block: true,
    types: true,
  },
  rust: {
    keywords: words(`${literals} fn let mut const static return if else for
      while loop match break continue struct enum impl trait type where pub
      use mod crate self Self super as in ref move async await dyn unsafe
      extern`),
    line: ["//"],
    block: true,
    types: true,
  },
  c: {
    keywords: words(`${literals} ${cLike} class public private protected
      virtual override template typename namespace using new delete this
      throw try catch nullptr constexpr`),
    line: ["//"],
    block: true,
    types: true,
  },
  java: {
    keywords: words(`${literals} ${cLike} class interface extends implements
      package import public private protected abstract final new this super
      throw throws try catch finally instanceof synchronized fun val var when
      object companion data sealed override open is in as let guard func
      struct protocol extension init deinit self import`),
    line: ["//"],
    block: true,
    types: true,
  },
  shell: {
    keywords: words(`if then else elif fi for in do done while until case esac
      function return export local readonly echo exit set unset source`),
    line: ["#"],
    block: false,
    types: false,
  },
  sql: {
    keywords: words(`${literals} select from where and or not insert into values
      update set delete create table drop alter index join left right inner
      outer on as group by order having limit offset distinct union all null
      primary key foreign references default is in like between case when then
      else end`),
    line: ["--"],
    block: true,
    types: false,
    caseless: true,
  },
};

const aliases: Record<string, string> = {
  javascript: "js", typescript: "js", ts: "js", jsx: "js", tsx: "js",
  json: "js", py: "python", golang: "go", rs: "rust", cpp: "c", "c++": "c",
  h: "c", hpp: "c", cs: "java", csharp: "java", kotlin: "java", kt: "java",
  swift: "java", objc: "c", sh: "shell", bash: "shell", zsh: "shell",
  console: "shell",
};

// Without a language: the keywords most languages share.
const generic: Grammar = {
  keywords: words(`${literals} if else for while do switch case default break
    continue return function func fn def class struct enum interface import
    export from package var let const final static public private new try
    catch finally throw async await`),
  line: ["//", "#"],
  block: true,
  types: true,
};

function grammarOf(language: string | undefined): Grammar {
  const name = (language ?? "").trim().toLowerCase();
  return grammars[aliases[name] ?? name] ?? generic;
}

// Sticky patterns, matched where the scan stands: one pass over the code.
const numberRe = /0[xX][\da-fA-F_]+|0[bB][01_]+|\d[\d_]*(?:\.\d+)?(?:[eE][+-]?\d+)?/y;
const nameRe = /[A-Za-z_$][\w$]*/y;
const spaceRe = /\s+/y;
const callRe = /\s*\(/y;
const isNameStart = /[A-Za-z_$]/;
const isDigit = /\d/;
const isWord = /[\w$]/;
const punctuation = "{}()[];,.:<>=+-*/%&|^!~?@";

function at(re: RegExp, code: string, i: number): string | undefined {
  re.lastIndex = i;
  return re.exec(code)?.[0];
}

function highlight(code: string, language?: string): { text: string; token: Token }[] {
  const g = grammarOf(language);
  const spans: { text: string; token: Token }[] = [];
  const push = (text: string, token: Token) => {
    const last = spans[spans.length - 1];
    if (last && last.token === token) last.text += text;
    else spans.push({ text, token });
  };
  let i = 0;
  while (i < code.length) {
    const ch = code[i];
    if (ch === " " || ch === "\t" || ch === "\n" || ch === "\r") {
      const space = at(spaceRe, code, i)!;
      push(space, "plain");
      i += space.length;
      continue;
    }
    if (g.line.some((o) => code.startsWith(o, i))) {
      const end = code.indexOf("\n", i);
      const stop = end < 0 ? code.length : end;
      push(code.slice(i, stop), "comment");
      i = stop;
      continue;
    }
    if (g.block && ch === "/" && code[i + 1] === "*") {
      const end = code.indexOf("*/", i + 2);
      const stop = end < 0 ? code.length : end + 2;
      push(code.slice(i, stop), "comment");
      i = stop;
      continue;
    }
    if (ch === '"' || ch === "'" || ch === "`") {
      const triple = code.startsWith(ch.repeat(3), i) ? ch.repeat(3) : ch;
      let j = i + triple.length;
      while (j < code.length && !code.startsWith(triple, j)) {
        // A one-quote string ends at the line end even when unclosed.
        if (triple.length === 1 && ch !== "`" && code[j] === "\n") break;
        j += code[j] === "\\" ? 2 : 1;
      }
      const stop = Math.min(code.length, code.startsWith(triple, j) ? j + triple.length : j);
      push(code.slice(i, stop), "string");
      i = stop;
      continue;
    }
    if (isDigit.test(ch) && !isWord.test(code[i - 1] ?? "")) {
      const number = at(numberRe, code, i)!;
      push(number, "number");
      i += number.length;
      continue;
    }
    if (isNameStart.test(ch)) {
      const word = at(nameRe, code, i)!;
      callRe.lastIndex = i + word.length;
      const call = callRe.test(code);
      const token: Token = g.keywords.has(g.caseless ? word.toLowerCase() : word)
        ? "keyword"
        : call
          ? "function"
          : g.types && /^[A-Z][a-z]/.test(word)
            ? "type"
            : "plain";
      push(word, token);
      i += word.length;
      continue;
    }
    push(ch, punctuation.includes(ch) ? "punctuation" : "plain");
    i += 1;
  }
  return spans;
}

mg.on("message.render.code", ({ code, language }): Mg.UiNode[] | void => {
  if (!code) return;
  return [{ type: "code", language, spans: highlight(code, language) }];
});
