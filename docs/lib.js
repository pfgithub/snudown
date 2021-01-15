let global_obj;
let gmem;
let on_obj_ready = [];
function escapeHTML(html) {
	return html
		.split("&").join("&amp;")
		.split('"').join("&quot;")
		.split("<").join("&lt;")
        .split(">").join("&gt;")
    ;
}
const enc = new TextEncoder();
const dec = new TextDecoder();
async function markdownToHTML(markdown) {
    const obj = global_obj ?? await new Promise(r => on_obj_ready.push(() => r(global_obj)));
    try{
        const utf8 = enc.encode(markdown);
        const strptr = obj.instance.exports.allocString(utf8.byteLength);
        const inmem = new Uint8Array(obj.instance.exports.memory.buffer, strptr, utf8.byteLength);
        inmem.set(utf8);
        const res = obj.instance.exports.markdownToHTML(strptr, utf8.byteLength);
        const outlen = obj.instance.exports.strlen(res);
        const outarr = new Uint8Array(obj.instance.exports.memory.buffer, res, outlen);
        const decoded = dec.decode(outarr);
        obj.instance.exports.freeText(strptr, utf8.byteLength);
        obj.instance.exports.freeText(res, outlen);
        return decoded;
    }catch(e){
        console.log(e.toString() + "\n" + e.stack);
        return escapeHTML("Error "+e.toString()+"\n"+e.stack);
    }
}
WebAssembly.instantiateStreaming(fetch("entry_wasm.wasm"), {
    env: {
        __assert_fail: (assertion, file, line, fn) => {
            console.log(assertion, file, line, fn);
            throw new Error("assert failed");
        },
        __stack_chk_fail: () => {
            throw new Error("stack overflow");
        },
        debugprints: (text, len) => {
            console.log("print text:",dec.decode(new Uint8Array(gmem.buffer, text, len)));
        },
        debugprinti: (intv) => {
            console.log("print int:", intv);
        },
        debugprintc: (intv) => {
            console.log("print char:", String.fromCodePoint(intv));
        },
        debugpanic: (text, len) => {
            throw new Error("Panic: "+ dec.decode(new Uint8Array(gmem.buffer, text, len)));
        }
    },
}).then(obj => {
    gmem = obj.instance.exports.memory;
    global_obj = obj;
    on_obj_ready.forEach(v => v());
    on_obj_ready = undefined;
}).catch(e => {
    console.log(e.toString(), e.stack);
    alert("errored, check console");
});

window.el = (nme) => document.createElement(nme);
window.txt = (txt) => document.createTextNode(txt);
window.anychange = (itms, cb) => (itms.forEach(itm => itm.oninput = () => cb()), cb());
window.body = document.getElementById("maincontent") ?? document.body;
Node.prototype.attr = function (atrs) { Object.entries(atrs).forEach(([k, v]) => this.setAttribute(k, v)); return this; };
Node.prototype.adto = function (prnt) { prnt.appendChild(this); return this; };
Node.prototype.adch = function (chld) { this.appendChild(chld); return this; };
Node.prototype.atxt = function (txta) { this.appendChild(txt(txta)); return this; };
Node.prototype.onev = function (evnm, cb) { this.addEventListener(evnm, cb); return this; };
Node.prototype.drmv = function (defer) { defer(() => this.remove()); return this; };
Node.prototype.clss = function (clss) { clss.split(".").filter(q => q).map(itm => this.classList.add(itm)); return this; };
