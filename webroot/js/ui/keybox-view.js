// The Keyboxes panel. The resting screen is the list of *.xml keyboxes on disk, each a
// row whose name is the inspect trigger plus Rename and Delete; Import is the panel-head
// primary and opens a bottom sheet (file picker + name field + Import) built by
// renderKeyboxImport. Inspecting opens a drill-in that pretty-prints the parsed
// certificate chains (renderKeyboxInspect). Pure
// DOM through el(); it renders from controller state and emits intents through `actions`.
// It never imports data/* or bridge/*. All text is textContent via el's `text`, never
// innerHTML.
//
// renderKeyboxes(mount, state, actions)
//   state   = { files }
//   actions = { onImport(), inspect(name), rename(name), delete(name) }
//
// renderKeyboxImport(state, actions) -> HTMLElement   (content for the import sheet)
//   state   = { importName, importContent, error }
//   actions = { pickFile(file), setImportName(str), import(), close() }
//
// renderKeyboxInspect(state, actions) -> HTMLElement  (content for the inspect drill-in)
//   state   = { name, data }   the /keybox/inspect response to pretty-print
//   actions = { close() }

import { el, clear } from "./dom.js";

export function renderKeyboxes(mount, state, actions) {
  clear(mount);
  const { files = [] } = state;

  mount.appendChild(el("div", { class: "panel-head" }, [
    el("h1", { class: "panel-title", text: "密钥盒" }),
    el("button", { class: "btn primary", text: "导入", onclick: () => actions.onImport() }),
  ]));

  if (!files.length) {
    mount.appendChild(el("div", { class: "card empty" },
      [el("p", { class: "muted", text: "暂无密钥盒。导入一个 *.xml 密钥盒以签署认证。" })]));
    return;
  }

  const list = el("ul", { class: "kb-list card" });
  for (const name of files) {
    list.appendChild(el("li", { class: "kb-row" }, [
      // The name is the inspect trigger: a small keybox badge + the filename, keyboard-reachable,
      // that wraps instead of shoving the Rename/Delete buttons off the row.
      el("button", {
        class: "kb-name mono", type: "button",
        title: "检查 " + name, onclick: () => actions.inspect(name),
      }, [
        el("span", { class: "kb-icon", "aria-hidden": "true" }),
        el("span", { class: "kb-file", text: name }),
      ]),
      el("div", { class: "keybtns" }, [
        el("button", { class: "btn small ghost", text: "重命名", onclick: () => actions.rename(name) }),
        el("button", { class: "btn small danger ghost", text: "删除", onclick: () => actions.delete(name) }),
      ]),
    ]));
  }
  mount.appendChild(list);
}

export function renderKeyboxImport(state, actions) {
  const { importName = "", importContent = "", error = null } = state;

  // No `accept` filter: Android's document picker greys out any file whose provider
  // MIME isn't an exact match (a keybox reports text/xml or octet-stream, not the
  // application/xml the filter asks for), so it looked like "no file is selectable".
  // We validate the content after reading instead, so any file can be chosen.
  const fileInput = el("input", {
    class: "input", type: "file",
    onchange: (e) => { const f = e.target.files && e.target.files[0]; if (f) actions.pickFile(f); },
  });
  // Bare keystrokes only sync the controller's field; they never re-render, so the
  // caret is never yanked mid-type. A discrete pickFile/import redraws.
  const nameInput = el("input", {
    class: "input", type: "text", value: importName, placeholder: "keybox.xml",
    autocapitalize: "off", autocorrect: "off", spellcheck: "false",
    oninput: (e) => actions.setImportName(e.target.value),
  });

  return el("div", {}, [
    el("div", { class: "sheet-head" }, [
      el("h2", { text: "导入密钥盒" }),
      el("button", { class: "iconbtn", type: "button", "aria-label": "Close", onclick: () => actions.close() }, [
        el("span", { class: "x-mark", "aria-hidden": "true" }),
      ]),
    ]),
    error ? el("div", { class: "banner error" }, [el("div", { text: error })]) : null,
    el("div", { class: "field" }, [el("span", { class: "field-label", text: "密钥盒文件" }), fileInput]),
    el("div", { class: "field" }, [el("span", { class: "field-label", text: "保存为" }), nameInput]),
    el("button", { class: "btn primary block sheet-submit", text: "导入", disabled: !importContent, onclick: () => actions.import() }),
    el("p", { class: "field-help", text: "文件将被复制到 /data/adb/teesim；名称字段将成为文件名。" }),
  ]);
}

// ---- inspect drill-in ---------------------------------------------------
export function renderKeyboxInspect(state, actions) {
  const { name = "", data = null } = state;

  const body = el("div", { class: "drill-body" }, [
    el("div", { class: "keyalias" }, [el("span", { class: "mono", text: name })]),
  ]);

  if (!data || data.ok === false) {
    body.appendChild(el("div", { class: "banner error" }, [
      el("div", { text: (data && data.error) || "无法检查此密钥盒。" }),
    ]));
  } else {
    if (data.deviceId) body.appendChild(el("div", { class: "muted small", text: "设备ID: " + data.deviceId }));
    const keys = Array.isArray(data.keys) ? data.keys : [];
    if (!keys.length) body.appendChild(el("p", { class: "muted", text: "此密钥盒中未找到 <Key> 块。" }));
    for (const k of keys) body.appendChild(keyBlock(k));
  }

  return el("div", {}, [
    el("div", { class: "drill-head" }, [
      el("button", { class: "iconbtn", type: "button", "aria-label": "返回密钥盒列表", onclick: () => actions.close() }, [
        el("span", { class: "chevron-left", "aria-hidden": "true" }),
      ]),
      el("h1", { class: "drill-title", text: "密钥盒", tabindex: "-1" }),
    ]),
    body,
  ]);
}

function keyBlock(k) {
  const linkage = k.linkage || "";
  const linkChip =
    linkage === "ok" ? el("span", { class: "chip good", text: "链验证通过" })
    : linkage === "broken" ? el("span", { class: "chip warn", text: "链已断开" })
    : linkage === "single" ? el("span", { class: "chip", text: "单证书" })
    : null;
  const head = el("div", { class: "kbi-head" }, [
    el("span", { class: "chip mono", text: (k.algorithm || "?").toUpperCase() }),
    el("span", { class: "chip", text: (k.chainLength || 0) + (k.chainLength === 1 ? " 个证书" : " 个证书") }),
    linkChip,
    k.privateKeyPresent
      ? el("span", { class: "chip good", text: "有私钥" })
      : el("span", { class: "chip warn", text: "无私钥" }),
  ]);
  const certs = Array.isArray(k.certs) ? k.certs : [];
  return el("div", { class: "card kbi-key" }, [head, ...certs.map(certBlock)]);
}

function certBlock(c) {
  if (c.error) {
    return el("div", { class: "kbi-cert" }, [el("div", { class: "err", text: "cert " + c.index + ": " + c.error })]);
  }
  const badges = el("div", { class: "chips" }, [
    el("span", { class: "chip", text: roleOf(c) }),
    el("span", { class: "chip mono", text: (c.keyAlgorithm || "?") + (c.keySize ? " " + c.keySize : "") }),
    c.expired ? el("span", { class: "chip warn", text: "已过期" }) : null,
    c.notYetValid ? el("span", { class: "chip warn", text: "尚未生效" }) : null,
  ]);
  return el("div", { class: "kbi-cert" }, [
    badges,
    kv("主题", c.subject),
    kv("颁发者", c.issuer),
    kv("序列号", c.serial),
    kv("有效期", fmtDate(c.notBefore) + "  →  " + fmtDate(c.notAfter)),
    kv("签名算法", c.sigAlg),
  ]);
}

function roleOf(c) {
  if (c.index === 0) return "叶证书";
  if (c.selfSigned) return "根证书";
  return c.isCa ? "中间证书" : "cert " + c.index;
}

function kv(label, value) {
  return el("div", { class: "kv kv-stack" }, [
    el("span", { class: "kv-label", text: label }),
    el("span", { class: "mono kv-hex", text: value == null || value === "" ? "—" : String(value) }),
  ]);
}

function fmtDate(ms) {
  const n = Number(ms);
  if (!Number.isFinite(n) || n <= 0) return "—";
  try { return new Date(n).toISOString().slice(0, 10); } catch { return String(ms); }
}
