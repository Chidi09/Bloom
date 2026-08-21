(function dartProgram(){function copyProperties(a,b){var s=Object.keys(a)
for(var r=0;r<s.length;r++){var q=s[r]
b[q]=a[q]}}function mixinPropertiesHard(a,b){var s=Object.keys(a)
for(var r=0;r<s.length;r++){var q=s[r]
if(!b.hasOwnProperty(q)){b[q]=a[q]}}}function mixinPropertiesEasy(a,b){Object.assign(b,a)}var z=function(){var s=function(){}
s.prototype={p:{}}
var r=new s()
if(!(Object.getPrototypeOf(r)&&Object.getPrototypeOf(r).p===s.prototype.p))return false
try{if(typeof navigator!="undefined"&&typeof navigator.userAgent=="string"&&navigator.userAgent.indexOf("Chrome/")>=0)return true
if(typeof version=="function"&&version.length==0){var q=version()
if(/^\d+\.\d+\.\d+\.\d+$/.test(q))return true}}catch(p){}return false}()
function inherit(a,b){a.prototype.constructor=a
a.prototype["$i"+a.name]=a
if(b!=null){if(z){Object.setPrototypeOf(a.prototype,b.prototype)
return}var s=Object.create(b.prototype)
copyProperties(a.prototype,s)
a.prototype=s}}function inheritMany(a,b){for(var s=0;s<b.length;s++){inherit(b[s],a)}}function mixinEasy(a,b){mixinPropertiesEasy(b.prototype,a.prototype)
a.prototype.constructor=a}function mixinHard(a,b){mixinPropertiesHard(b.prototype,a.prototype)
a.prototype.constructor=a}function lazy(a,b,c,d){var s=a
a[b]=s
a[c]=function(){if(a[b]===s){a[b]=d()}a[c]=function(){return this[b]}
return a[b]}}function lazyFinal(a,b,c,d){var s=a
a[b]=s
a[c]=function(){if(a[b]===s){var r=d()
if(a[b]!==s){A.iZ(b)}a[b]=r}var q=a[b]
a[c]=function(){return q}
return q}}function makeConstList(a,b){if(b!=null)A.c(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var s=0;s<a.length;++s){convertToFastObject(a[s])}}var y=0
function instanceTearOffGetter(a,b){var s=null
return a?function(c){if(s===null)s=A.ep(b)
return new s(c,this)}:function(){if(s===null)s=A.ep(b)
return new s(this,null)}}function staticTearOffGetter(a){var s=null
return function(){if(s===null)s=A.ep(a).prototype
return s}}var x=0
function tearOffParameters(a,b,c,d,e,f,g,h,i,j){if(typeof h=="number"){h+=x}return{co:a,iS:b,iI:c,rC:d,dV:e,cs:f,fs:g,fT:h,aI:i||0,nDA:j}}function installStaticTearOff(a,b,c,d,e,f,g,h){var s=tearOffParameters(a,true,false,c,d,e,f,g,h,false)
var r=staticTearOffGetter(s)
a[b]=r}function installInstanceTearOff(a,b,c,d,e,f,g,h,i,j){c=!!c
var s=tearOffParameters(a,false,c,d,e,f,g,h,i,!!j)
var r=instanceTearOffGetter(c,s)
a[b]=r}function setOrUpdateInterceptorsByTag(a){var s=v.interceptorsByTag
if(!s){v.interceptorsByTag=a
return}copyProperties(a,s)}function setOrUpdateLeafTags(a){var s=v.leafTags
if(!s){v.leafTags=a
return}copyProperties(a,s)}function updateTypes(a){var s=v.types
var r=s.length
s.push.apply(s,a)
return r}function updateHolder(a,b){copyProperties(b,a)
return a}var hunkHelpers=function(){var s=function(a,b,c,d,e){return function(f,g,h,i){return installInstanceTearOff(f,g,a,b,c,d,[h],i,e,false)}},r=function(a,b,c,d){return function(e,f,g,h){return installStaticTearOff(e,f,a,b,c,[g],h,d)}}
return{inherit:inherit,inheritMany:inheritMany,mixin:mixinEasy,mixinHard:mixinHard,installStaticTearOff:installStaticTearOff,installInstanceTearOff:installInstanceTearOff,_instance_0u:s(0,0,null,["$0"],0),_instance_1u:s(0,1,null,["$1"],0),_instance_2u:s(0,2,null,["$2"],0),_instance_0i:s(1,0,null,["$0"],0),_instance_1i:s(1,1,null,["$1"],0),_instance_2i:s(1,2,null,["$2"],0),_static_0:r(0,null,["$0"],0),_static_1:r(1,null,["$1"],0),_static_2:r(2,null,["$2"],0),makeConstList:makeConstList,lazy:lazy,lazyFinal:lazyFinal,updateHolder:updateHolder,convertToFastObject:convertToFastObject,updateTypes:updateTypes,setOrUpdateInterceptorsByTag:setOrUpdateInterceptorsByTag,setOrUpdateLeafTags:setOrUpdateLeafTags}}()
function initializeDeferredHunk(a){x=v.types.length
a(hunkHelpers,v,w,$)}var J={
eu(a,b,c,d){return{i:a,p:b,e:c,x:d}},
er(a){var s,r,q,p,o,n="_$dart_js",m=a[v.dispatchPropertyName]
if(m==null)if($.es==null){A.iP()
m=a[v.dispatchPropertyName]}if(m!=null){s=m.p
if(!1===s)return m.i
if(!0===s)return a
r=Object.getPrototypeOf(a)
if(s===r)return m.i
if(m.e===r)throw A.e(A.eT("Return interceptor for "+A.o(s(a,m))))}q=a.constructor
if(q==null)p=null
else{o=$.dr
if(o==null)o=$.dr=A.dU(n)
p=q[o]}if(p!=null)return p
p=A.iT(a)
if(p!=null)return p
if(typeof a=="function")return B.z
s=Object.getPrototypeOf(a)
if(s==null)return B.l
if(s===Object.prototype)return B.l
if(typeof q=="function"){o=$.dr
if(o==null)o=$.dr=A.dU(n)
Object.defineProperty(q,o,{value:B.e,enumerable:false,writable:true,configurable:true})
return B.e}return B.e},
fZ(a,b){if(a<0||a>4294967295)throw A.e(A.cU(a,0,4294967295,"length",null))
return J.h0(new Array(a),b)},
h_(a,b){if(a<0)throw A.e(A.ax("Length must be a non-negative integer: "+a,null))
return A.c(new Array(a),b.i("t<0>"))},
eJ(a,b){if(a<0)throw A.e(A.ax("Length must be a non-negative integer: "+a,null))
return A.c(new Array(a),b.i("t<0>"))},
h0(a,b){var s=A.c(a,b.i("t<0>"))
s.$flags=1
return s},
eK(a){if(a<256)switch(a){case 9:case 10:case 11:case 12:case 13:case 32:case 133:case 160:return!0
default:return!1}switch(a){case 5760:case 8192:case 8193:case 8194:case 8195:case 8196:case 8197:case 8198:case 8199:case 8200:case 8201:case 8202:case 8232:case 8233:case 8239:case 8287:case 12288:case 65279:return!0
default:return!1}},
h1(a,b){var s,r
for(s=a.length;b<s;){r=a.charCodeAt(b)
if(r!==32&&r!==13&&!J.eK(r))break;++b}return b},
h2(a,b){var s,r
for(;b>0;b=s){s=b-1
r=a.charCodeAt(s)
if(r!==32&&r!==13&&!J.eK(r))break}return b},
a9(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.aE.prototype
return J.bx.prototype}if(typeof a=="string")return J.aj.prototype
if(a==null)return J.aF.prototype
if(typeof a=="boolean")return J.bw.prototype
if(Array.isArray(a))return J.t.prototype
if(typeof a!="object"){if(typeof a=="function")return J.O.prototype
if(typeof a=="symbol")return J.aJ.prototype
if(typeof a=="bigint")return J.aH.prototype
return a}if(a instanceof A.i)return a
return J.er(a)},
fp(a){if(typeof a=="string")return J.aj.prototype
if(a==null)return a
if(Array.isArray(a))return J.t.prototype
if(typeof a!="object"){if(typeof a=="function")return J.O.prototype
if(typeof a=="symbol")return J.aJ.prototype
if(typeof a=="bigint")return J.aH.prototype
return a}if(a instanceof A.i)return a
return J.er(a)},
dT(a){if(a==null)return a
if(Array.isArray(a))return J.t.prototype
if(typeof a!="object"){if(typeof a=="function")return J.O.prototype
if(typeof a=="symbol")return J.aJ.prototype
if(typeof a=="bigint")return J.aH.prototype
return a}if(a instanceof A.i)return a
return J.er(a)},
ez(a,b){if(a==null)return b==null
if(typeof a!="object")return b!=null&&a===b
return J.a9(a).B(a,b)},
eA(a,b){return J.dT(a).E(a,b)},
fL(a,b){return J.dT(a).M(a,b)},
cg(a){return J.a9(a).gn(a)},
e3(a){return J.dT(a).gp(a)},
fM(a){return J.fp(a).gu(a)},
fN(a){return J.a9(a).gm(a)},
e4(a,b,c){return J.dT(a).F(a,b,c)},
bf(a){return J.a9(a).h(a)},
bu:function bu(){},
bw:function bw(){},
aF:function aF(){},
aI:function aI(){},
P:function P(){},
bR:function bR(){},
aV:function aV(){},
O:function O(){},
aH:function aH(){},
aJ:function aJ(){},
t:function t(a){this.$ti=a},
bv:function bv(){},
cK:function cK(a){this.$ti=a},
bh:function bh(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
aG:function aG(){},
aE:function aE(){},
bx:function bx(){},
aj:function aj(){}},A={ea:function ea(){},
h3(a){return new A.aK("Field '"+a+"' has not been initialized.")},
fn(a,b,c){return a},
et(a){var s,r
for(s=$.a7.length,r=0;r<s;++r)if(a===$.a7[r])return!0
return!1},
h5(a,b,c,d){if(t.V.b(a))return new A.U(a,b,c.i("@<0>").t(d).i("U<1,2>"))
return new A.a1(a,b,c.i("@<0>").t(d).i("a1<1,2>"))},
aK:function aK(a){this.a=a},
f:function f(){},
E:function E(){},
ak:function ak(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
a1:function a1(a,b,c){this.a=a
this.b=b
this.$ti=c},
U:function U(a,b,c){this.a=a
this.b=b
this.$ti=c},
bD:function bD(a,b,c){var _=this
_.a=null
_.b=a
_.c=b
_.$ti=c},
I:function I(a,b,c){this.a=a
this.b=b
this.$ti=c},
aB:function aB(){},
fx(a){var s=A.fw(a)
if(s!=null)return s
return"minified:"+a},
jj(a,b){var s
if(b!=null){s=b.x
if(s!=null)return s}return t.p.b(a)},
o(a){var s
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
s=J.bf(a)
return s},
bT(a){var s,r=$.eN
if(r==null)r=$.eN=Symbol("identityHashCode")
s=a[r]
if(s==null){s=Math.random()*0x3fffffff|0
a[r]=s}return s},
h9(a){var s,r
if(!/^\s*[+-]?(?:Infinity|NaN|(?:\.\d+|\d+(?:\.\d*)?)(?:[eE][+-]?\d+)?)\s*$/.test(a))return null
s=parseFloat(a)
if(isNaN(s)){r=B.d.bh(a)
if(r==="NaN"||r==="+NaN"||r==="-NaN")return s
return null}return s},
bU(a){var s,r,q,p
if(a instanceof A.i)return A.A(A.av(a),null)
s=J.a9(a)
if(s===B.y||s===B.A||t.o.b(a)){r=B.f(a)
if(r!=="Object"&&r!=="")return r
q=a.constructor
if(typeof q=="function"){p=q.name
if(typeof p=="string"&&p!=="Object"&&p!=="")return p}}return A.A(A.av(a),null)},
ha(a){var s,r,q
if(typeof a=="number"||A.dM(a))return J.bf(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.M)return a.h(0)
s=$.fK()
for(r=0;r<1;++r){q=s[r].bi(a)
if(q!=null)return q}return"Instance of '"+A.bU(a)+"'"},
h6(){return Date.now()},
h8(){var s,r
if($.cS!==0)return
$.cS=1000
if(typeof window=="undefined")return
s=window
if(s==null)return
if(!!s.dartUseDateNowForTicks)return
r=s.performance
if(r==null)return
if(typeof r.now!="function")return
$.cS=1e6
$.cT=new A.cR(r)},
h7(a){var s=a.$thrownJsError
if(s==null)return null
return A.aa(s)},
iE(a){return new A.G(!0,a,null,null)},
e(a){return A.v(a,new Error())},
v(a,b){var s
if(a==null)a=new A.J()
b.dartException=a
s=A.j_
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:s})
b.name=""}else b.toString=s
return b},
j_(){return J.bf(this.dartException)},
e2(a,b){throw A.v(a,b==null?new Error():b)},
fv(a,b,c){var s
if(b==null)b=0
if(c==null)c=0
s=Error()
A.e2(A.hX(a,b,c),s)},
hX(a,b,c){var s,r,q,p,o,n,m,l,k
if(typeof b=="string")s=b
else{r="[]=;add;removeWhere;retainWhere;removeRange;setRange;setInt8;setInt16;setInt32;setUint8;setUint16;setUint32;setFloat32;setFloat64".split(";")
q=r.length
p=b
if(p>q){c=p/q|0
p%=q}s=r[p]}o=typeof c=="string"?c:"modify;remove from;add to".split(";")[c]
n=t.j.b(a)?"list":"ByteData"
m=a.$flags|0
l="a "
if((m&4)!==0)k="constant "
else if((m&2)!==0){k="unmodifiable "
l="an "}else k=(m&1)!==0?"fixed-length ":""
return new A.aW("'"+s+"': Cannot "+o+" "+l+k+n)},
be(a){throw A.e(A.N(a))},
K(a){var s,r,q,p,o,n
a=A.iY(a.replace(String({}),"$receiver$"))
s=a.match(/\\\$[a-zA-Z]+\\\$/g)
if(s==null)s=A.c([],t.s)
r=s.indexOf("\\$arguments\\$")
q=s.indexOf("\\$argumentsExpr\\$")
p=s.indexOf("\\$expr\\$")
o=s.indexOf("\\$method\\$")
n=s.indexOf("\\$receiver\\$")
return new A.d6(a.replace(new RegExp("\\\\\\$arguments\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$argumentsExpr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$expr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$method\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$receiver\\\\\\$","g"),"((?:x|[^x])*)"),r,q,p,o,n)},
d7(a){return function($expr$){var $argumentsExpr$="$arguments$"
try{$expr$.$method$($argumentsExpr$)}catch(s){return s.message}}(a)},
eS(a){return function($expr$){try{$expr$.$method$}catch(s){return s.message}}(a)},
eb(a,b){var s=b==null,r=s?null:b.method
return new A.by(a,r,s?null:b.receiver)},
ad(a){if(a==null)return new A.cQ(a)
if(a instanceof A.bo)return A.S(a,a.a)
if(typeof a!=="object")return a
if("dartException" in a)return A.S(a,a.dartException)
return A.iC(a)},
S(a,b){if(t.Q.b(b))if(b.$thrownJsError==null)b.$thrownJsError=a
return b},
iC(a){var s,r,q,p,o,n,m,l,k,j,i,h,g
if(!("message" in a))return a
s=a.message
if("number" in a&&typeof a.number=="number"){r=a.number
q=r&65535
if((B.b.aR(r,16)&8191)===10)switch(q){case 438:return A.S(a,A.eb(A.o(s)+" (Error "+q+")",null))
case 445:case 5007:A.o(s)
return A.S(a,new A.aQ())}}if(a instanceof TypeError){p=$.fA()
o=$.fB()
n=$.fC()
m=$.fD()
l=$.fG()
k=$.fH()
j=$.fF()
$.fE()
i=$.fJ()
h=$.fI()
g=p.q(s)
if(g!=null)return A.S(a,A.eb(s,g))
else{g=o.q(s)
if(g!=null){g.method="call"
return A.S(a,A.eb(s,g))}else if(n.q(s)!=null||m.q(s)!=null||l.q(s)!=null||k.q(s)!=null||j.q(s)!=null||m.q(s)!=null||i.q(s)!=null||h.q(s)!=null)return A.S(a,new A.aQ())}return A.S(a,new A.c5(typeof s=="string"?s:""))}if(a instanceof RangeError){if(typeof s=="string"&&s.indexOf("call stack")!==-1)return new A.aU()
s=function(b){try{return String(b)}catch(f){}return null}(a)
return A.S(a,new A.G(!1,null,null,typeof s=="string"?s.replace(/^RangeError:\s*/,""):s))}if(typeof InternalError=="function"&&a instanceof InternalError)if(typeof s=="string"&&s==="too much recursion")return new A.aU()
return a},
aa(a){var s
if(a instanceof A.bo)return a.b
if(a==null)return new A.b6(a)
s=a.$cachedTrace
if(s!=null)return s
s=new A.b6(a)
if(typeof a==="object")a.$cachedTrace=s
return s},
ev(a){if(a==null)return J.cg(a)
if(typeof a=="object")return A.bT(a)
return J.cg(a)},
iM(a,b){var s,r,q,p=a.length
for(s=0;s<p;s=q){r=s+1
q=r+1
b.A(0,a[s],a[r])}return b},
i5(a,b,c,d,e,f){switch(b){case 0:return a.$0()
case 1:return a.$1(c)
case 2:return a.$2(c,d)
case 3:return a.$3(c,d,e)
case 4:return a.$4(c,d,e,f)}throw A.e(A.eH("Unsupported number of arguments for wrapped closure"))},
ce(a,b){var s=a.$identity
if(!!s)return s
s=A.iI(a,b)
a.$identity=s
return s},
iI(a,b){var s
switch(b){case 0:s=a.$0
break
case 1:s=a.$1
break
case 2:s=a.$2
break
case 3:s=a.$3
break
case 4:s=a.$4
break
default:s=null}if(s!=null)return s.bind(a)
return function(c,d,e){return function(f,g,h,i){return e(c,d,f,g,h,i)}}(a,b,A.i5)},
fU(a2){var s,r,q,p,o,n,m,l,k,j,i=a2.co,h=a2.iS,g=a2.iI,f=a2.nDA,e=a2.aI,d=a2.fs,c=a2.cs,b=d[0],a=c[0],a0=i[b],a1=a2.fT
a1.toString
s=h?Object.create(new A.c1().constructor.prototype):Object.create(new A.ag(null,null).constructor.prototype)
s.$initialize=s.constructor
r=h?function static_tear_off(){this.$initialize()}:function tear_off(a3,a4){this.$initialize(a3,a4)}
s.constructor=r
r.prototype=s
s.$_name=b
s.$_target=a0
q=!h
if(q)p=A.eG(b,a0,g,f)
else{s.$static_name=b
p=a0}s.$S=A.fQ(a1,h,g)
s[a]=p
for(o=p,n=1;n<d.length;++n){m=d[n]
if(typeof m=="string"){l=i[m]
k=m
m=l}else k=""
j=c[n]
if(j!=null){if(q)m=A.eG(k,m,g,f)
s[j]=m}if(n===e)o=m}s.$C=o
s.$R=a2.rC
s.$D=a2.dV
return r},
fQ(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.e("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.fO)}throw A.e("Error in functionType of tearoff")},
fR(a,b,c,d){var s=A.eF
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,s)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,s)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,s)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,s)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,s)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,s)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,s)}},
eG(a,b,c,d){if(c)return A.fT(a,b,d)
return A.fR(b.length,d,a,b)},
fS(a,b,c,d){var s=A.eF,r=A.fP
switch(b?-1:a){case 0:throw A.e(new A.bX("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,r,s)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,r,s)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,r,s)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,r,s)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,r,s)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,r,s)
default:return function(e,f,g){return function(){var q=[g(this)]
Array.prototype.push.apply(q,arguments)
return e.apply(f(this),q)}}(d,r,s)}},
fT(a,b,c){var s,r
if($.eD==null)$.eD=A.eC("interceptor")
if($.eE==null)$.eE=A.eC("receiver")
s=b.length
r=A.fS(s,c,a,b)
return r},
ep(a){return A.fU(a)},
fO(a,b){return A.dB(v.typeUniverse,A.av(a.a),b)},
eF(a){return a.a},
fP(a){return a.b},
eC(a){var s,r,q,p=new A.ag("receiver","interceptor"),o=Object.getOwnPropertyNames(p)
o.$flags=1
s=o
for(o=s.length,r=0;r<o;++r){q=s[r]
if(p[q]===a)return q}throw A.e(A.ax("Field name "+a+" not found.",null))},
dU(a){return v.getIsolateTag(a)},
iT(a){var s,r,q,p,o,n=$.fr.$1(a),m=$.dS[n]
if(m!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}s=$.dY[n]
if(s!=null)return s
r=v.interceptorsByTag[n]
if(r==null){q=$.fl.$2(a,n)
if(q!=null){m=$.dS[q]
if(m!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}s=$.dY[q]
if(s!=null)return s
r=v.interceptorsByTag[q]
n=q}}if(r==null)return null
s=r.prototype
p=n[0]
if(p==="!"){m=A.e1(s)
$.dS[n]=m
Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}if(p==="~"){$.dY[n]=s
return s}if(p==="-"){o=A.e1(s)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:o,enumerable:false,writable:true,configurable:true})
return o.i}if(p==="+")return A.ft(a,s)
if(p==="*")throw A.e(A.eT(n))
if(v.leafTags[n]===true){o=A.e1(s)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:o,enumerable:false,writable:true,configurable:true})
return o.i}else return A.ft(a,s)},
ft(a,b){var s=Object.getPrototypeOf(a)
Object.defineProperty(s,v.dispatchPropertyName,{value:J.eu(b,s,null,null),enumerable:false,writable:true,configurable:true})
return b},
e1(a){return J.eu(a,!1,null,!!a.$iz)},
iV(a,b,c){var s=b.prototype
if(v.leafTags[a]===true)return A.e1(s)
else return J.eu(s,c,null,null)},
iP(){if(!0===$.es)return
$.es=!0
A.iQ()},
iQ(){var s,r,q,p,o,n,m,l
$.dS=Object.create(null)
$.dY=Object.create(null)
A.iO()
s=v.interceptorsByTag
r=Object.getOwnPropertyNames(s)
if(typeof window!="undefined"){window
q=function(){}
for(p=0;p<r.length;++p){o=r[p]
n=$.fu.$1(o)
if(n!=null){m=A.iV(o,s[o],n)
if(m!=null){Object.defineProperty(n,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
q.prototype=n}}}}for(p=0;p<r.length;++p){o=r[p]
if(/^[A-Za-z_]/.test(o)){l=s[o]
s["!"+o]=l
s["~"+o]=l
s["-"+o]=l
s["+"+o]=l
s["*"+o]=l}}},
iO(){var s,r,q,p,o,n,m=B.m()
m=A.au(B.n,A.au(B.o,A.au(B.h,A.au(B.h,A.au(B.p,A.au(B.q,A.au(B.r(B.f),m)))))))
if(typeof dartNativeDispatchHooksTransformer!="undefined"){s=dartNativeDispatchHooksTransformer
if(typeof s=="function")s=[s]
if(Array.isArray(s))for(r=0;r<s.length;++r){q=s[r]
if(typeof q=="function")m=q(m)||m}}p=m.getTag
o=m.getUnknownTag
n=m.prototypeForTag
$.fr=new A.dV(p)
$.fl=new A.dW(o)
$.fu=new A.dX(n)},
au(a,b){return a(b)||b},
iJ(a,b){var s=b.length,r=v.rttc[""+s+";"+a]
if(r==null)return null
if(s===0)return r
if(s===r.length)return r.apply(null,b)
return r(b)},
iY(a){if(/[[\]{}()*+?.\\^$|]/.test(a))return a.replace(/[[\]{}()*+?.\\^$|]/g,"\\$&")
return a},
cR:function cR(a){this.a=a},
aS:function aS(){},
d6:function d6(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
aQ:function aQ(){},
by:function by(a,b,c){this.a=a
this.b=b
this.c=c},
c5:function c5(a){this.a=a},
cQ:function cQ(a){this.a=a},
bo:function bo(){},
b6:function b6(a){this.a=a
this.b=null},
M:function M(){},
bk:function bk(){},
bl:function bl(){},
c3:function c3(){},
c1:function c1(){},
ag:function ag(a,b){this.a=a
this.b=b},
bX:function bX(a){this.a=a},
X:function X(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
cL:function cL(a,b){var _=this
_.a=a
_.b=b
_.d=_.c=null},
aL:function aL(a,b){this.a=a
this.$ti=b},
bA:function bA(a,b,c){var _=this
_.a=a
_.b=b
_.c=c
_.d=null},
Y:function Y(a,b){this.a=a
this.$ti=b},
bz:function bz(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
dV:function dV(a){this.a=a},
dW:function dW(a){this.a=a},
dX:function dX(a){this.a=a},
al:function al(){},
aO:function aO(){},
bE:function bE(){},
am:function am(){},
aM:function aM(){},
aN:function aN(){},
bF:function bF(){},
bG:function bG(){},
bH:function bH(){},
bI:function bI(){},
bJ:function bJ(){},
bK:function bK(){},
bL:function bL(){},
aP:function aP(){},
bM:function bM(){},
b1:function b1(){},
b2:function b2(){},
b3:function b3(){},
b4:function b4(){},
ee(a,b){var s=b.c
return s==null?b.c=A.ba(a,"aD",[b.x]):s},
eO(a){var s=a.w
if(s===6||s===7)return A.eO(a.x)
return s===11||s===12},
hc(a){return a.as},
eq(a){return A.dA(v.typeUniverse,a,!1)},
a6(a1,a2,a3,a4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=a2.w
switch(a0){case 5:case 1:case 2:case 3:case 4:return a2
case 6:s=a2.x
r=A.a6(a1,s,a3,a4)
if(r===s)return a2
return A.f2(a1,r,!0)
case 7:s=a2.x
r=A.a6(a1,s,a3,a4)
if(r===s)return a2
return A.f1(a1,r,!0)
case 8:q=a2.y
p=A.at(a1,q,a3,a4)
if(p===q)return a2
return A.ba(a1,a2.x,p)
case 9:o=a2.x
n=A.a6(a1,o,a3,a4)
m=a2.y
l=A.at(a1,m,a3,a4)
if(n===o&&l===m)return a2
return A.ei(a1,n,l)
case 10:k=a2.x
j=a2.y
i=A.at(a1,j,a3,a4)
if(i===j)return a2
return A.f3(a1,k,i)
case 11:h=a2.x
g=A.a6(a1,h,a3,a4)
f=a2.y
e=A.iz(a1,f,a3,a4)
if(g===h&&e===f)return a2
return A.f0(a1,g,e)
case 12:d=a2.y
a4+=d.length
c=A.at(a1,d,a3,a4)
o=a2.x
n=A.a6(a1,o,a3,a4)
if(c===d&&n===o)return a2
return A.ej(a1,n,c,!0)
case 13:b=a2.x
if(b<a4)return a2
a=a3[b-a4]
if(a==null)return a2
return a
default:throw A.e(A.bj("Attempted to substitute unexpected RTI kind "+a0))}},
at(a,b,c,d){var s,r,q,p,o=b.length,n=A.dC(o)
for(s=!1,r=0;r<o;++r){q=b[r]
p=A.a6(a,q,c,d)
if(p!==q)s=!0
n[r]=p}return s?n:b},
iA(a,b,c,d){var s,r,q,p,o,n,m=b.length,l=A.dC(m)
for(s=!1,r=0;r<m;r+=3){q=b[r]
p=b[r+1]
o=b[r+2]
n=A.a6(a,o,c,d)
if(n!==o)s=!0
l.splice(r,3,q,p,n)}return s?l:b},
iz(a,b,c,d){var s,r=b.a,q=A.at(a,r,c,d),p=b.b,o=A.at(a,p,c,d),n=b.c,m=A.iA(a,n,c,d)
if(q===r&&o===p&&m===n)return b
s=new A.c8()
s.a=q
s.b=o
s.c=m
return s},
c(a,b){a[v.arrayRti]=b
return a},
fo(a){var s=a.$S
if(s!=null){if(typeof s=="number")return A.iN(s)
return a.$S()}return null},
iR(a,b){var s
if(A.eO(b))if(a instanceof A.M){s=A.fo(a)
if(s!=null)return s}return A.av(a)},
av(a){if(a instanceof A.i)return A.a4(a)
if(Array.isArray(a))return A.dE(a)
return A.em(J.a9(a))},
dE(a){var s=a[v.arrayRti],r=t.b
if(s==null)return r
if(s.constructor!==r.constructor)return r
return s},
a4(a){var s=a.$ti
return s!=null?s:A.em(a)},
em(a){var s=a.constructor,r=s.$ccache
if(r!=null)return r
return A.i3(a,s)},
i3(a,b){var s=a instanceof A.M?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,r=A.hF(v.typeUniverse,s.name)
b.$ccache=r
return r},
iN(a){var s,r=v.types,q=r[a]
if(typeof q=="string"){s=A.dA(v.typeUniverse,q,!1)
r[a]=s
return s}return q},
fq(a){return A.a8(A.a4(a))},
iy(a){var s=a instanceof A.M?A.fo(a):null
if(s!=null)return s
if(t.R.b(a))return J.fN(a).a
if(Array.isArray(a))return A.dE(a)
return A.av(a)},
a8(a){var s=a.r
return s==null?a.r=new A.dz(a):s},
F(a){return A.a8(A.dA(v.typeUniverse,a,!1))},
i2(a){var s=this
s.b=A.iw(s)
return s.b(a)},
iw(a){var s,r,q,p
if(a===t.K)return A.ic
if(A.ab(a))return A.ih
s=a.w
if(s===6)return A.i0
if(s===1)return A.ff
if(s===7)return A.i6
r=A.iv(a)
if(r!=null)return r
if(s===8){q=a.x
if(a.y.every(A.ab)){a.f="$i"+q
if(q==="n")return A.ia
if(a===t.m)return A.i9
return A.ig}}else if(s===10){p=A.iJ(a.x,a.y)
return p==null?A.ff:p}return A.hZ},
iv(a){if(a.w===8){if(a===t.S)return A.i7
if(a===t.i||a===t.H)return A.ib
if(a===t.N)return A.ie
if(a===t.y)return A.dM}return null},
i1(a){var s=this,r=A.hY
if(A.ab(s))r=A.hS
else if(s===t.K)r=A.hQ
else if(A.aw(s)){r=A.i_
if(s===t.x)r=A.hM
else if(s===t.u)r=A.hR
else if(s===t.r)r=A.hI
else if(s===t.n)r=A.hP
else if(s===t.I)r=A.hK
else if(s===t.G)r=A.hN}else if(s===t.S)r=A.hL
else if(s===t.N)r=A.f8
else if(s===t.y)r=A.f7
else if(s===t.H)r=A.hO
else if(s===t.i)r=A.hJ
else if(s===t.m)r=A.cd
s.a=r
return s.a(a)},
hZ(a){var s=this
if(a==null)return A.aw(s)
return A.iS(v.typeUniverse,A.iR(a,s),s)},
i0(a){if(a==null)return!0
return this.x.b(a)},
ig(a){var s,r=this
if(a==null)return A.aw(r)
s=r.f
if(a instanceof A.i)return!!a[s]
return!!J.a9(a)[s]},
ia(a){var s,r=this
if(a==null)return A.aw(r)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
s=r.f
if(a instanceof A.i)return!!a[s]
return!!J.a9(a)[s]},
i9(a){var s=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.i)return!!a[s.f]
return!0}if(typeof a=="function")return!0
return!1},
fe(a){if(typeof a=="object"){if(a instanceof A.i)return t.m.b(a)
return!0}if(typeof a=="function")return!0
return!1},
hY(a){var s=this
if(a==null){if(A.aw(s))return a}else if(s.b(a))return a
throw A.v(A.fa(a,s),new Error())},
i_(a){var s=this
if(a==null||s.b(a))return a
throw A.v(A.fa(a,s),new Error())},
fa(a,b){return new A.b8("TypeError: "+A.eU(a,A.A(b,null)))},
eU(a,b){return A.cy(a)+": type '"+A.A(A.iy(a),null)+"' is not a subtype of type '"+b+"'"},
B(a,b){return new A.b8("TypeError: "+A.eU(a,b))},
i6(a){var s=this
return s.x.b(a)||A.ee(v.typeUniverse,s).b(a)},
ic(a){return a!=null},
hQ(a){if(a!=null)return a
throw A.v(A.B(a,"Object"),new Error())},
ih(a){return!0},
hS(a){return a},
ff(a){return!1},
dM(a){return!0===a||!1===a},
f7(a){if(!0===a)return!0
if(!1===a)return!1
throw A.v(A.B(a,"bool"),new Error())},
hI(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.v(A.B(a,"bool?"),new Error())},
hJ(a){if(typeof a=="number")return a
throw A.v(A.B(a,"double"),new Error())},
hK(a){if(typeof a=="number")return a
if(a==null)return a
throw A.v(A.B(a,"double?"),new Error())},
i7(a){return typeof a=="number"&&Math.floor(a)===a},
hL(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.v(A.B(a,"int"),new Error())},
hM(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.v(A.B(a,"int?"),new Error())},
ib(a){return typeof a=="number"},
hO(a){if(typeof a=="number")return a
throw A.v(A.B(a,"num"),new Error())},
hP(a){if(typeof a=="number")return a
if(a==null)return a
throw A.v(A.B(a,"num?"),new Error())},
ie(a){return typeof a=="string"},
f8(a){if(typeof a=="string")return a
throw A.v(A.B(a,"String"),new Error())},
hR(a){if(typeof a=="string")return a
if(a==null)return a
throw A.v(A.B(a,"String?"),new Error())},
cd(a){if(A.fe(a))return a
throw A.v(A.B(a,"JSObject"),new Error())},
hN(a){if(a==null)return a
if(A.fe(a))return a
throw A.v(A.B(a,"JSObject?"),new Error())},
fj(a,b){var s,r,q
for(s="",r="",q=0;q<a.length;++q,r=", ")s+=r+A.A(a[q],b)
return s},
ir(a,b){var s,r,q,p,o,n,m=a.x,l=a.y
if(""===m)return"("+A.fj(l,b)+")"
s=l.length
r=m.split(",")
q=r.length-s
for(p="(",o="",n=0;n<s;++n,o=", "){p+=o
if(q===0)p+="{"
p+=A.A(l[n],b)
if(q>=0)p+=" "+r[q];++q}return p+"})"},
fb(a1,a2,a3){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a=", ",a0=null
if(a3!=null){s=a3.length
if(a2==null)a2=A.c([],t.s)
else a0=a2.length
r=a2.length
for(q=s;q>0;--q)a2.push("T"+(r+q))
for(p=t.X,o="<",n="",q=0;q<s;++q,n=a){o=o+n+a2[a2.length-1-q]
m=a3[q]
l=m.w
if(!(l===2||l===3||l===4||l===5||m===p))o+=" extends "+A.A(m,a2)}o+=">"}else o=""
p=a1.x
k=a1.y
j=k.a
i=j.length
h=k.b
g=h.length
f=k.c
e=f.length
d=A.A(p,a2)
for(c="",b="",q=0;q<i;++q,b=a)c+=b+A.A(j[q],a2)
if(g>0){c+=b+"["
for(b="",q=0;q<g;++q,b=a)c+=b+A.A(h[q],a2)
c+="]"}if(e>0){c+=b+"{"
for(b="",q=0;q<e;q+=3,b=a){c+=b
if(f[q+1])c+="required "
c+=A.A(f[q+2],a2)+" "+f[q]}c+="}"}if(a0!=null){a2.toString
a2.length=a0}return o+"("+c+") => "+d},
A(a,b){var s,r,q,p,o,n,m=a.w
if(m===5)return"erased"
if(m===2)return"dynamic"
if(m===3)return"void"
if(m===1)return"Never"
if(m===4)return"any"
if(m===6){s=a.x
r=A.A(s,b)
q=s.w
return(q===11||q===12?"("+r+")":r)+"?"}if(m===7)return"FutureOr<"+A.A(a.x,b)+">"
if(m===8){p=A.iB(a.x)
o=a.y
return o.length>0?p+("<"+A.fj(o,b)+">"):p}if(m===10)return A.ir(a,b)
if(m===11)return A.fb(a,b,null)
if(m===12)return A.fb(a.x,b,a.y)
if(m===13){n=a.x
return b[b.length-1-n]}return"?"},
iB(a){var s=A.fw(a)
if(s!=null)return s
return"minified:"+a},
hG(a,b){var s=a.tR[b]
while(typeof s=="string")s=a.tR[s]
return s},
hF(a,b){var s,r,q,p,o,n=a.eT,m=n[b]
if(m==null)return A.dA(a,b,!1)
else if(typeof m=="number"){s=m
r=A.bb(a,5,"#")
q=A.dC(s)
for(p=0;p<s;++p)q[p]=r
o=A.ba(a,b,q)
n[b]=o
return o}else return m},
hD(a,b){return A.f5(a.tR,b)},
hC(a,b){return A.f5(a.eT,b)},
dA(a,b,c){var s,r=a.eC,q=r.get(b)
if(q!=null)return q
s=A.f4(a,null,b,!1)
r.set(b,s)
return s},
dB(a,b,c){var s,r,q=b.z
if(q==null)q=b.z=new Map()
s=q.get(c)
if(s!=null)return s
r=A.f4(a,b,c,!0)
q.set(c,r)
return r},
hE(a,b,c){var s,r,q,p=b.Q
if(p==null)p=b.Q=new Map()
s=c.as
r=p.get(s)
if(r!=null)return r
q=A.ei(a,b,c.w===9?c.y:[c])
p.set(s,q)
return q},
f4(a,b,c,d){return A.ht(A.hn(a,b,c,d))},
R(a,b){b.a=A.i1
b.b=A.i2
return b},
bb(a,b,c){var s,r,q=a.eC.get(c)
if(q!=null)return q
s=new A.C(null,null)
s.w=b
s.as=c
r=A.R(a,s)
a.eC.set(c,r)
return r},
f2(a,b,c){var s,r=b.as+"?",q=a.eC.get(r)
if(q!=null)return q
s=A.hA(a,b,r,c)
a.eC.set(r,s)
return s},
hA(a,b,c,d){var s,r,q
if(d){s=b.w
r=!0
if(!A.ab(b))if(!(b===t.P||b===t.T))if(s!==6)r=s===7&&A.aw(b.x)
if(r)return b
else if(s===1)return t.P}q=new A.C(null,null)
q.w=6
q.x=b
q.as=c
return A.R(a,q)},
f1(a,b,c){var s,r=b.as+"/",q=a.eC.get(r)
if(q!=null)return q
s=A.hy(a,b,r,c)
a.eC.set(r,s)
return s},
hy(a,b,c,d){var s,r
if(d){s=b.w
if(A.ab(b)||b===t.K)return b
else if(s===1)return A.ba(a,"aD",[b])
else if(b===t.P||b===t.T)return t.h}r=new A.C(null,null)
r.w=7
r.x=b
r.as=c
return A.R(a,r)},
hB(a,b){var s,r,q=""+b+"^",p=a.eC.get(q)
if(p!=null)return p
s=new A.C(null,null)
s.w=13
s.x=b
s.as=q
r=A.R(a,s)
a.eC.set(q,r)
return r},
b9(a){var s,r,q,p=a.length
for(s="",r="",q=0;q<p;++q,r=",")s+=r+a[q].as
return s},
hx(a){var s,r,q,p,o,n=a.length
for(s="",r="",q=0;q<n;q+=3,r=","){p=a[q]
o=a[q+1]?"!":":"
s+=r+p+o+a[q+2].as}return s},
ba(a,b,c){var s,r,q,p=b
if(c.length>0)p+="<"+A.b9(c)+">"
s=a.eC.get(p)
if(s!=null)return s
r=new A.C(null,null)
r.w=8
r.x=b
r.y=c
if(c.length>0)r.c=c[0]
r.as=p
q=A.R(a,r)
a.eC.set(p,q)
return q},
ei(a,b,c){var s,r,q,p,o,n
if(b.w===9){s=b.x
r=b.y.concat(c)}else{r=c
s=b}q=s.as+(";<"+A.b9(r)+">")
p=a.eC.get(q)
if(p!=null)return p
o=new A.C(null,null)
o.w=9
o.x=s
o.y=r
o.as=q
n=A.R(a,o)
a.eC.set(q,n)
return n},
f3(a,b,c){var s,r,q="+"+(b+"("+A.b9(c)+")"),p=a.eC.get(q)
if(p!=null)return p
s=new A.C(null,null)
s.w=10
s.x=b
s.y=c
s.as=q
r=A.R(a,s)
a.eC.set(q,r)
return r},
f0(a,b,c){var s,r,q,p,o,n=b.as,m=c.a,l=m.length,k=c.b,j=k.length,i=c.c,h=i.length,g="("+A.b9(m)
if(j>0){s=l>0?",":""
g+=s+"["+A.b9(k)+"]"}if(h>0){s=l>0?",":""
g+=s+"{"+A.hx(i)+"}"}r=n+(g+")")
q=a.eC.get(r)
if(q!=null)return q
p=new A.C(null,null)
p.w=11
p.x=b
p.y=c
p.as=r
o=A.R(a,p)
a.eC.set(r,o)
return o},
ej(a,b,c,d){var s,r=b.as+("<"+A.b9(c)+">"),q=a.eC.get(r)
if(q!=null)return q
s=A.hz(a,b,c,r,d)
a.eC.set(r,s)
return s},
hz(a,b,c,d,e){var s,r,q,p,o,n,m,l
if(e){s=c.length
r=A.dC(s)
for(q=0,p=0;p<s;++p){o=c[p]
if(o.w===1){r[p]=o;++q}}if(q>0){n=A.a6(a,b,r,0)
m=A.at(a,c,r,0)
return A.ej(a,n,m,c!==m)}}l=new A.C(null,null)
l.w=12
l.x=b
l.y=c
l.as=d
return A.R(a,l)},
hn(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
ht(a){var s,r,q,p,o,n,m,l=a.r,k=a.s
for(s=l.length,r=0;r<s;){q=l.charCodeAt(r)
if(q>=48&&q<=57)r=A.hp(r+1,q,l,k)
else if((((q|32)>>>0)-97&65535)<26||q===95||q===36||q===124)r=A.eZ(a,r,l,k,!1)
else if(q===46)r=A.eZ(a,r,l,k,!0)
else{++r
switch(q){case 44:break
case 58:k.push(!1)
break
case 33:k.push(!0)
break
case 59:k.push(A.a2(a.u,a.e,k.pop()))
break
case 94:k.push(A.hB(a.u,k.pop()))
break
case 35:k.push(A.bb(a.u,5,"#"))
break
case 64:k.push(A.bb(a.u,2,"@"))
break
case 126:k.push(A.bb(a.u,3,"~"))
break
case 60:k.push(a.p)
a.p=k.length
break
case 62:A.hr(a,k)
break
case 38:A.hq(a,k)
break
case 63:p=a.u
k.push(A.f2(p,A.a2(p,a.e,k.pop()),a.n))
break
case 47:p=a.u
k.push(A.f1(p,A.a2(p,a.e,k.pop()),a.n))
break
case 40:k.push(-3)
k.push(a.p)
a.p=k.length
break
case 41:A.ho(a,k)
break
case 91:k.push(a.p)
a.p=k.length
break
case 93:o=k.splice(a.p)
A.f_(a.u,a.e,o)
a.p=k.pop()
k.push(o)
k.push(-1)
break
case 123:k.push(a.p)
a.p=k.length
break
case 125:o=k.splice(a.p)
A.hu(a.u,a.e,o)
a.p=k.pop()
k.push(o)
k.push(-2)
break
case 43:n=l.indexOf("(",r)
k.push(l.substring(r,n))
k.push(-4)
k.push(a.p)
a.p=k.length
r=n+1
break
default:throw"Bad character "+q}}}m=k.pop()
return A.a2(a.u,a.e,m)},
hp(a,b,c,d){var s,r,q=b-48
for(s=c.length;a<s;++a){r=c.charCodeAt(a)
if(!(r>=48&&r<=57))break
q=q*10+(r-48)}d.push(q)
return a},
eZ(a,b,c,d,e){var s,r,q,p,o,n,m=b+1
for(s=c.length;m<s;++m){r=c.charCodeAt(m)
if(r===46){if(e)break
e=!0}else{if(!((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124))q=r>=48&&r<=57
else q=!0
if(!q)break}}p=c.substring(b,m)
if(e){s=a.u
o=a.e
if(o.w===9)o=o.x
n=A.hG(s,o.x)[p]
if(n==null)A.e2('No "'+p+'" in "'+A.hc(o)+'"')
d.push(A.dB(s,o,n))}else d.push(p)
return m},
hr(a,b){var s,r=a.u,q=A.eY(a,b),p=b.pop()
if(typeof p=="string")b.push(A.ba(r,p,q))
else{s=A.a2(r,a.e,p)
switch(s.w){case 11:b.push(A.ej(r,s,q,a.n))
break
default:b.push(A.ei(r,s,q))
break}}},
ho(a,b){var s,r,q,p=a.u,o=b.pop(),n=null,m=null
if(typeof o=="number")switch(o){case-1:n=b.pop()
break
case-2:m=b.pop()
break
default:b.push(o)
break}else b.push(o)
s=A.eY(a,b)
o=b.pop()
switch(o){case-3:o=b.pop()
if(n==null)n=p.sEA
if(m==null)m=p.sEA
r=A.a2(p,a.e,o)
q=new A.c8()
q.a=s
q.b=n
q.c=m
b.push(A.f0(p,r,q))
return
case-4:b.push(A.f3(p,b.pop(),s))
return
default:throw A.e(A.bj("Unexpected state under `()`: "+A.o(o)))}},
hq(a,b){var s=b.pop()
if(0===s){b.push(A.bb(a.u,1,"0&"))
return}if(1===s){b.push(A.bb(a.u,4,"1&"))
return}throw A.e(A.bj("Unexpected extended operation "+A.o(s)))},
eY(a,b){var s=b.splice(a.p)
A.f_(a.u,a.e,s)
a.p=b.pop()
return s},
a2(a,b,c){if(typeof c=="string")return A.ba(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.hs(a,b,c)}else return c},
f_(a,b,c){var s,r=c.length
for(s=0;s<r;++s)c[s]=A.a2(a,b,c[s])},
hu(a,b,c){var s,r=c.length
for(s=2;s<r;s+=3)c[s]=A.a2(a,b,c[s])},
hs(a,b,c){var s,r,q=b.w
if(q===9){if(c===0)return b.x
s=b.y
r=s.length
if(c<=r)return s[c-1]
c-=r
b=b.x
q=b.w}else if(c===0)return b
if(q!==8)throw A.e(A.bj("Indexed base must be an interface type"))
s=b.y
if(c<=s.length)return s[c-1]
throw A.e(A.bj("Bad index "+c+" for "+b.h(0)))},
iS(a,b,c){var s,r=b.d
if(r==null)r=b.d=new Map()
s=r.get(c)
if(s==null){s=A.u(a,b,null,c,null)
r.set(c,s)}return s},
u(a,b,c,d,e){var s,r,q,p,o,n,m,l,k,j,i
if(b===d)return!0
if(A.ab(d))return!0
s=b.w
if(s===4)return!0
if(A.ab(b))return!1
if(b.w===1)return!0
r=s===13
if(r)if(A.u(a,c[b.x],c,d,e))return!0
q=d.w
p=t.P
if(b===p||b===t.T){if(q===7)return A.u(a,b,c,d.x,e)
return d===p||d===t.T||q===6}if(d===t.K){if(s===7)return A.u(a,b.x,c,d,e)
return s!==6}if(s===7){if(!A.u(a,b.x,c,d,e))return!1
return A.u(a,A.ee(a,b),c,d,e)}if(s===6)return A.u(a,p,c,d,e)&&A.u(a,b.x,c,d,e)
if(q===7){if(A.u(a,b,c,d.x,e))return!0
return A.u(a,b,c,A.ee(a,d),e)}if(q===6)return A.u(a,b,c,p,e)||A.u(a,b,c,d.x,e)
if(r)return!1
p=s!==11
if((!p||s===12)&&d===t.Z)return!0
o=s===10
if(o&&d===t.d)return!0
if(q===12){if(b===t.g)return!0
if(s!==12)return!1
n=b.y
m=d.y
l=n.length
if(l!==m.length)return!1
c=c==null?n:n.concat(c)
e=e==null?m:m.concat(e)
for(k=0;k<l;++k){j=n[k]
i=m[k]
if(!A.u(a,j,c,i,e)||!A.u(a,i,e,j,c))return!1}return A.fd(a,b.x,c,d.x,e)}if(q===11){if(b===t.g)return!0
if(p)return!1
return A.fd(a,b,c,d,e)}if(s===8){if(q!==8)return!1
return A.i8(a,b,c,d,e)}if(o&&q===10)return A.id(a,b,c,d,e)
return!1},
fd(a3,a4,a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2
if(!A.u(a3,a4.x,a5,a6.x,a7))return!1
s=a4.y
r=a6.y
q=s.a
p=r.a
o=q.length
n=p.length
if(o>n)return!1
m=n-o
l=s.b
k=r.b
j=l.length
i=k.length
if(o+j<n+i)return!1
for(h=0;h<o;++h){g=q[h]
if(!A.u(a3,p[h],a7,g,a5))return!1}for(h=0;h<m;++h){g=l[h]
if(!A.u(a3,p[o+h],a7,g,a5))return!1}for(h=0;h<i;++h){g=l[m+h]
if(!A.u(a3,k[h],a7,g,a5))return!1}f=s.c
e=r.c
d=f.length
c=e.length
for(b=0,a=0;a<c;a+=3){a0=e[a]
for(;;){if(b>=d)return!1
a1=f[b]
b+=3
if(a0<a1)return!1
a2=f[b-2]
if(a1<a0){if(a2)return!1
continue}g=e[a+1]
if(a2&&!g)return!1
g=f[b-1]
if(!A.u(a3,e[a+2],a7,g,a5))return!1
break}}while(b<d){if(f[b+1])return!1
b+=3}return!0},
i8(a,b,c,d,e){var s,r,q,p,o,n=b.x,m=d.x
while(n!==m){s=a.tR[n]
if(s==null)return!1
if(typeof s=="string"){n=s
continue}r=s[m]
if(r==null)return!1
q=r.length
p=q>0?new Array(q):v.typeUniverse.sEA
for(o=0;o<q;++o)p[o]=A.dB(a,b,r[o])
return A.f6(a,p,null,c,d.y,e)}return A.f6(a,b.y,null,c,d.y,e)},
f6(a,b,c,d,e,f){var s,r=b.length
for(s=0;s<r;++s)if(!A.u(a,b[s],d,e[s],f))return!1
return!0},
id(a,b,c,d,e){var s,r=b.y,q=d.y,p=r.length
if(p!==q.length)return!1
if(b.x!==d.x)return!1
for(s=0;s<p;++s)if(!A.u(a,r[s],c,q[s],e))return!1
return!0},
aw(a){var s=a.w,r=!0
if(!(a===t.P||a===t.T))if(!A.ab(a))if(s!==6)r=s===7&&A.aw(a.x)
return r},
ab(a){var s=a.w
return s===2||s===3||s===4||s===5||a===t.X},
f5(a,b){var s,r,q=Object.keys(b),p=q.length
for(s=0;s<p;++s){r=q[s]
a[r]=b[r]}},
dC(a){return a>0?new Array(a):v.typeUniverse.sEA},
C:function C(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
c8:function c8(){this.c=this.b=this.a=null},
dz:function dz(a){this.a=a},
c7:function c7(){},
b8:function b8(a){this.a=a},
hi(){var s,r,q
if(self.scheduleImmediate!=null)return A.iF()
if(self.MutationObserver!=null&&self.document!=null){s={}
r=self.document.createElement("div")
q=self.document.createElement("span")
s.a=null
new self.MutationObserver(A.ce(new A.dd(s),1)).observe(r,{childList:true})
return new A.dc(s,r,q)}else if(self.setImmediate!=null)return A.iG()
return A.iH()},
hj(a){self.scheduleImmediate(A.ce(new A.de(a),0))},
hk(a){self.setImmediate(A.ce(new A.df(a),0))},
hl(a){A.ef(B.v,a)},
ef(a,b){return A.hv(a.a/1000|0,b)},
eR(a,b){return A.hw(a.a/1000|0,b)},
hv(a,b){var s=new A.b7()
s.aD(a,b)
return s},
hw(a,b){var s=new A.b7()
s.aE(a,b)
return s},
e5(a){var s
if(t.Q.b(a)){s=a.gG()
if(s!=null)return s}return B.u},
eI(a,b,c){var s=new A.D($.r,c.i("D<0>"))
A.hg(a,new A.cD(b,s,c))
return s},
i4(a,b){if($.r===B.c)return null
return null},
eg(a,b,c){var s,r,q,p={},o=p.a=a
while(s=o.a,(s&4)!==0){o=o.c
p.a=o}if(o===b){s=A.eP()
b.aJ(new A.H(new A.G(!0,o,null,"Cannot complete a future with itself"),s))
return}r=b.a&1
s=o.a=s|r
if((s&24)===0){q=b.c
b.a=b.a&1|4
b.c=o
o.ac(q)
return}if(!c)if(b.c==null)o=(s&16)===0||r!==0
else o=!1
else o=!0
if(o){q=b.K()
b.I(p.a)
A.aq(b,q)
return}b.a^=2
A.dR(null,null,b.b,new A.dj(p,b))},
aq(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g={},f=g.a=a
for(;;){s={}
r=f.a
q=(r&16)===0
p=!q
if(b==null){if(p&&(r&1)===0){f=f.c
A.dP(f.a,f.b)}return}s.a=b
o=b.a
for(f=b;o!=null;f=o,o=n){f.a=null
A.aq(g.a,f)
s.a=o
n=o.a}r=g.a
m=r.c
s.b=p
s.c=m
if(q){l=f.c
l=(l&1)!==0||(l&15)===8}else l=!0
if(l){k=f.b.b
if(p){r=r.b===k
r=!(r||r)}else r=!1
if(r){A.dP(m.a,m.b)
return}j=$.r
if(j!==k)$.r=k
else j=null
f=f.c
if((f&15)===8)new A.dn(s,g,p).$0()
else if(q){if((f&1)!==0)new A.dm(s,m).$0()}else if((f&2)!==0)new A.dl(g,s).$0()
if(j!=null)$.r=j
f=s.c
if(f instanceof A.D){r=s.a.$ti
r=r.i("aD<2>").b(f)||!r.y[1].b(f)}else r=!1
if(r){i=s.a.b
if((f.a&24)!==0){h=i.c
i.c=null
b=i.L(h)
i.a=f.a&30|i.a&1
i.c=f.c
g.a=f
continue}else A.eg(f,i,!0)
return}}i=s.a.b
h=i.c
i.c=null
b=i.L(h)
f=s.b
r=s.c
if(!f){i.a=8
i.c=r}else{i.a=i.a&1|16
i.c=r}g.a=i
f=i}},
is(a,b){if(t.C.b(a))return b.b5(a)
if(t.v.b(a))return a
throw A.e(A.eB(a,"onError",u.c))},
io(){var s,r
for(s=$.as;s!=null;s=$.as){$.bd=null
r=s.b
$.as=r
if(r==null)$.bc=null
s.a.$0()}},
ix(){$.en=!0
try{A.io()}finally{$.bd=null
$.en=!1
if($.as!=null)$.ey().$1(A.fm())}},
fk(a){var s=new A.c6(a),r=$.bc
if(r==null){$.as=$.bc=s
if(!$.en)$.ey().$1(A.fm())}else $.bc=r.b=s},
iu(a){var s,r,q,p=$.as
if(p==null){A.fk(a)
$.bd=$.bc
return}s=new A.c6(a)
r=$.bd
if(r==null){s.b=p
$.as=$.bd=s}else{q=r.b
s.b=q
$.bd=r.b=s
if(q==null)$.bc=s}},
hg(a,b){var s=$.r
if(s===B.c)return A.ef(a,b)
return A.ef(a,s.ag(b))},
hh(a,b){var s=$.r
if(s===B.c)return A.eR(a,b)
return A.eR(a,s.aV(b,t.D))},
dP(a,b){A.iu(new A.dQ(a,b))},
fh(a,b,c,d){var s,r=$.r
if(r===c)return d.$0()
$.r=c
s=r
try{r=d.$0()
return r}finally{$.r=s}},
fi(a,b,c,d,e){var s,r=$.r
if(r===c)return d.$1(e)
$.r=c
s=r
try{r=d.$1(e)
return r}finally{$.r=s}},
it(a,b,c,d,e,f){var s,r=$.r
if(r===c)return d.$2(e,f)
$.r=c
s=r
try{r=d.$2(e,f)
return r}finally{$.r=s}},
dR(a,b,c,d){if(B.c!==c){d=c.ag(d)
d=d}A.fk(d)},
dd:function dd(a){this.a=a},
dc:function dc(a,b,c){this.a=a
this.b=b
this.c=c},
de:function de(a){this.a=a},
df:function df(a){this.a=a},
b7:function b7(){this.c=0},
dy:function dy(a,b){this.a=a
this.b=b},
dx:function dx(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
H:function H(a,b){this.a=a
this.b=b},
cD:function cD(a,b,c){this.a=a
this.b=b
this.c=c},
c9:function c9(a,b,c,d,e){var _=this
_.a=null
_.b=a
_.c=b
_.d=c
_.e=d
_.$ti=e},
D:function D(a,b){var _=this
_.a=0
_.b=a
_.c=null
_.$ti=b},
dh:function dh(a,b){this.a=a
this.b=b},
dk:function dk(a,b){this.a=a
this.b=b},
dj:function dj(a,b){this.a=a
this.b=b},
di:function di(a,b){this.a=a
this.b=b},
dn:function dn(a,b,c){this.a=a
this.b=b
this.c=c},
dp:function dp(a,b){this.a=a
this.b=b},
dq:function dq(a){this.a=a},
dm:function dm(a,b){this.a=a
this.b=b},
dl:function dl(a,b){this.a=a
this.b=b},
c6:function c6(a){this.a=a
this.b=null},
dD:function dD(){},
du:function du(){},
dv:function dv(a,b){this.a=a
this.b=b},
dw:function dw(a,b,c){this.a=a
this.b=b
this.c=c},
dQ:function dQ(a,b){this.a=a
this.b=b},
eV(a,b){var s=a[b]
return s===a?null:s},
eW(a,b,c){if(c==null)a[b]=a
else a[b]=c},
hm(){var s=Object.create(null)
A.eW(s,"<non-identifier-key>",s)
delete s["<non-identifier-key>"]
return s},
Z(a,b,c){return A.iM(a,new A.X(b.i("@<0>").t(c).i("X<1,2>")))},
eL(a,b){return new A.X(a.i("@<0>").t(b).i("X<1,2>"))},
cM(a){return new A.b0(a.i("b0<0>"))},
eh(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s},
eX(a,b,c){var s=new A.ar(a,b,c.i("ar<0>"))
s.c=a.e
return s},
eM(a){var s,r
if(A.et(a))return"{...}"
s=new A.c2("")
try{r={}
$.a7.push(a)
s.a+="{"
r.a=!0
a.V(0,new A.cN(r,s))
s.a+="}"}finally{$.a7.pop()}r=s.a
return r.charCodeAt(0)==0?r:r},
aY:function aY(){},
b_:function b_(a){var _=this
_.a=0
_.e=_.d=_.c=_.b=null
_.$ti=a},
aZ:function aZ(a,b){this.a=a
this.$ti=b},
ca:function ca(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
b0:function b0(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
ds:function ds(a){this.a=a
this.c=this.b=null},
ar:function ar(a,b,c){var _=this
_.a=a
_.b=b
_.d=_.c=null
_.$ti=c},
q:function q(){},
a_:function a_(){},
cN:function cN(a,b){this.a=a
this.b=b},
an:function an(){},
b5:function b5(){},
iK(a){var s=A.h9(a)
if(s!=null)return s
throw A.e(new A.cC("Invalid double",a))},
fW(a,b){a=A.v(a,new Error())
a.stack=b.h(0)
throw a},
h4(a,b,c,d){var s,r=c?J.h_(a,d):J.fZ(a,d)
if(a!==0&&b!=null)for(s=0;s<r.length;++s)r[s]=b
return r},
ec(a,b){var s,r
if(Array.isArray(a))return A.c(a.slice(0),b.i("t<0>"))
s=A.c([],b.i("t<0>"))
for(r=J.e3(a);r.k();)s.push(r.gl())
return s},
eQ(a,b,c){var s=J.e3(b)
if(!s.k())return a
if(c.length===0){do a+=A.o(s.gl())
while(s.k())}else{a+=A.o(s.gl())
while(s.k())a=a+c+A.o(s.gl())}return a},
eP(){return A.aa(new Error())},
cy(a){if(typeof a=="number"||A.dM(a)||a==null)return J.bf(a)
if(typeof a=="string")return JSON.stringify(a)
return A.ha(a)},
fX(a,b){A.fn(a,"error",t.K)
A.fn(b,"stackTrace",t.l)
A.fW(a,b)},
bj(a){return new A.bi(a)},
ax(a,b){return new A.G(!1,null,b,a)},
eB(a,b,c){return new A.G(!0,a,b,c)},
cU(a,b,c,d,e){return new A.bV(b,c,!0,a,d,"Invalid value")},
hb(a,b,c){if(0>a||a>c)throw A.e(A.cU(a,0,c,"start",null))
if(a>b||b>c)throw A.e(A.cU(b,a,c,"end",null))
return b},
aX(a){return new A.aW(a)},
eT(a){return new A.c4(a)},
hf(a){return new A.c0(a)},
N(a){return new A.bm(a)},
eH(a){return new A.dg(a)},
fY(a,b,c){var s,r
if(A.et(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}s=A.c([],t.s)
$.a7.push(a)
try{A.ii(a,s)}finally{$.a7.pop()}r=A.eQ(b,s,", ")+c
return r.charCodeAt(0)==0?r:r},
e9(a,b,c){var s,r
if(A.et(a))return b+"..."+c
s=new A.c2(b)
$.a7.push(a)
try{r=s
r.a=A.eQ(r.a,a,", ")}finally{$.a7.pop()}s.a+=c
r=s.a
return r.charCodeAt(0)==0?r:r},
ii(a,b){var s,r,q,p,o,n,m,l=a.gp(a),k=0,j=0
for(;;){if(!(k<80||j<3))break
if(!l.k())return
s=A.o(l.gl())
b.push(s)
k+=s.length+2;++j}if(!l.k()){if(j<=5)return
r=b.pop()
q=b.pop()}else{p=l.gl();++j
if(!l.k()){if(j<=4){b.push(A.o(p))
return}r=A.o(p)
q=b.pop()
k+=r.length+2}else{o=l.gl();++j
for(;l.k();p=o,o=n){n=l.gl();++j
if(j>100){for(;;){if(!(k>75&&j>3))break
k-=b.pop().length+2;--j}b.push("...")
return}}q=A.o(p)
r=A.o(o)
k+=r.length+q.length+4}}if(j>b.length+2){k+=5
m="..."}else m=null
for(;;){if(!(k>80&&b.length>3))break
k-=b.pop().length+2
if(m==null){k+=5
m="..."}}if(m!=null)b.push(m)
b.push(q)
b.push(r)},
ai:function ai(a){this.a=a},
m:function m(){},
bi:function bi(a){this.a=a},
J:function J(){},
G:function G(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
bV:function bV(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.a=c
_.b=d
_.c=e
_.d=f},
aW:function aW(a){this.a=a},
c4:function c4(a){this.a=a},
c0:function c0(a){this.a=a},
bm:function bm(a){this.a=a},
bO:function bO(){},
aU:function aU(){},
dg:function dg(a){this.a=a},
cC:function cC(a,b){this.a=a
this.b=b},
d:function d(){},
a0:function a0(a,b,c){this.a=a
this.b=b
this.$ti=c},
w:function w(){},
i:function i(){},
cc:function cc(){},
d1:function d1(){this.b=this.a=0},
c2:function c2(a){this.a=a},
dL(a){var s
if(typeof a=="function")throw A.e(A.ax("Attempting to rewrap a JS function.",null))
s=function(b,c){return function(d){return b(c,d,arguments.length)}}(A.hV,a)
s[$.ew()]=a
return s},
hV(a,b,c){if(c>=1)return a.$1(b)
return a.$0()},
fg(a){return a==null||A.dM(a)||typeof a=="number"||typeof a=="string"||t.U.b(a)||t.F.b(a)||t.f.b(a)||t.W.b(a)||t.E.b(a)||t.k.b(a)||t.w.b(a)||t.B.b(a)||t.q.b(a)||t.J.b(a)||t.Y.b(a)},
dZ(a){if(A.fg(a))return a
return new A.e_(new A.b_(t.A)).$1(a)},
e_:function e_(a){this.a=a},
af:function af(){},
im(a,b){var s=b.a
if(s===0)return null
return b},
a5(a,b,c,d,e){var s=c==null
if(s)return null
s=A.eL(t.N,t.co)
if(c!=null)s.A(0,"click",c)
return s},
h(a,b){var s=null
return new A.T("div",s,b,s,s,A.a5(s,s,s,s,s),a)},
a(a,b){var s=null
return new A.ao("span",b,a,s,s,A.a5(s,s,s,s,s),B.a)},
bQ(a,b){var s=null
return new A.bP("p",b,a,s,s,A.a5(s,s,s,s,s),B.a)},
e8(a,b){var s=null
return new A.br("h2",b,a,s,s,A.a5(s,s,s,s,s),B.a)},
ay(a,b,c,d){var s=null
return new A.ah("button",d,b,s,s,A.a5(s,s,c,s,s),a)},
ae(a,b,c,d){var s=null,r=t.N
r=A.eL(r,r)
r.A(0,"href",c)
return new A.bg("a",d,b,s,A.im(s,r),A.a5(s,s,s,s,s),a)},
cV(a,b,c){return new A.bY("section",null,c,null,a,null,b)},
ed(a){var s=null
return new A.bS("pre",s,s,s,s,s,a)},
l:function l(){},
aA:function aA(){},
aC:function aC(){},
bB:function bB(){},
bW:function bW(){},
V:function V(a){this.a=a},
y:function y(a){this.a=a},
x:function x(a){this.a=a},
T:function T(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
ao:function ao(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
bP:function bP(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
bq:function bq(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
br:function br(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
bs:function bs(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
ah:function ah(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
bg:function bg(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
bt:function bt(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
bp:function bp(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
bC:function bC(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
bN:function bN(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
bY:function bY(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
bS:function bS(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
iW(a,b){var s,r,q=A.cM(t.M),p=A.dO(a,new A.cb(q))
for(s=p.length,r=0;r<p.length;p.length===s||(0,A.be)(p),++r)b.appendChild(p[r])
A.ec(q,q.$ti.c)
return new A.cs()},
dO(a5,a6){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2=null,a3=a5 instanceof A.x,a4=a3?a5.a:a2
if(a3){s=v.G.document.createElement("span")
s.innerHTML=a4
return A.c([s],t.O)}r=a5 instanceof A.aA
q=a2
p=a2
o=a2
n=a2
m=a2
l=a2
if(r){k=a5.a
j=a5.b
o=a5.c
n=a5.e
m=a5.f
q=a5.r
l=q
p=j}else k=a2
if(r){a3=v.G
i=a3.document.createElement(k)
if(o!=null)i.className=o
if(n!=null)for(h=new A.Y(n,A.a4(n).i("Y<1,2>")).gp(0);h.k();){g=h.d
i.setAttribute(g.a,g.b)}if(m!=null)for(h=new A.Y(m,A.a4(m).i("Y<1,2>")).gp(0);h.k();){f=h.d
A.hT(i,f.a,f.b)}if(p!=null)i.appendChild(a3.document.createTextNode(p))
for(a3=l.length,e=0;e<l.length;l.length===a3||(0,A.be)(l),++e){d=A.dO(l[e],a6)
for(h=d.length,c=0;c<d.length;d.length===h||(0,A.be)(d),++c)i.appendChild(d[c])}return A.c([i],t.O)}b=a5 instanceof A.aC
if(b)l=a5.a
else l=a2
if(b){a=A.c([],t.O)
for(a3=l.length,e=0;e<l.length;l.length===a3||(0,A.be)(l),++e)B.j.af(a,A.dO(l[e],a6))
return a}a3=a5 instanceof A.y
a0=a3?a5.a:a2
if(a3){a1=v.G.document.createElement("span")
a1.setAttribute("data-bloom-live","")
A.hU(a1,a6,a0,a2)
return A.c([a1],t.O)}},
hU(a,b,c,d){var s=new A.cb(A.cM(t.M))
b.a.E(0,new A.dH(A.iL(new A.dI(new A.dJ(s,c,d,a))),s))},
hT(a,b,c){a.addEventListener(b,A.dL(new A.dF(b,c)))},
iD(a,b){var s,r,q,p=null,o=null
try{s=b.target
if(s!=null){r=s
p=A.ik(r,"value")
o=A.ij(r,"checked")}}catch(q){}return new A.af()},
ik(a,b){var s,r,q
try{s=v.G.Reflect.get(a,b)
if(s==null)return null
if(s!=null&&typeof s==="string"){r=A.f8(s)
return r}return null}catch(q){return null}},
ij(a,b){var s,r,q
try{s=v.G.Reflect.get(a,b)
if(s==null)return null
if(s!=null&&typeof s==="boolean"){r=A.f7(s)
return r}return null}catch(q){return null}},
cs:function cs(){},
cb:function cb(a){this.a=a},
dJ:function dJ(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
dI:function dI(a){this.a=a},
dH:function dH(a,b){this.a=a
this.b=b},
dF:function dF(a,b){this.a=a
this.b=b},
ch:function ch(a){this.a=a},
cl:function cl(a){this.a=a},
cj:function cj(a){this.a=a},
ck:function ck(a){this.a=a},
cm:function cm(a){this.a=a},
cn:function cn(a){this.a=a},
co:function co(a){this.a=a},
cp:function cp(a){this.a=a},
cq:function cq(a){this.a=a},
cr:function cr(a){this.a=a},
ci:function ci(){},
ct:function ct(a){this.a=a},
cw:function cw(a){this.a=a},
cv:function cv(a,b,c){this.a=a
this.b=b
this.c=c},
cu:function cu(a,b){this.a=a
this.b=b},
cz:function cz(){},
cE:function cE(a){this.a=a},
cG:function cG(a){this.a=a},
cF:function cF(a){this.a=a},
cO:function cO(a){this.a=a},
cP:function cP(a){this.a=a},
iU(){var s,r,q=null,p="hover:text-white transition-colors",o=$.fz(),n=new A.cz(),m=t.N,l=t.t,k=A.h(A.c([new A.cO(o).v(),new A.bC("main",q,"flex-1 flex flex-col",q,q,q,A.c([new A.cE(o).v(),new A.ch(o).v(),A.cV(A.Z(["id","features"],m,m),A.c([A.h(A.c([A.a(u.a,"Core Architecture"),A.e8(u.d,"Engineered for Zero Overhead"),A.bQ("text-zinc-400 text-base leading-relaxed","A web-first framework written in Dart that compiles pure AST descriptors directly to the DOM and server SSR without canvas or virtual DOM bloat.")],l),"text-center max-w-3xl mx-auto mb-16"),A.h(A.c([n.H("The exact same Dart AST descriptors execute in <1ms on server isolates to output SEO-optimized static HTML, then seamlessly activate fine-grained signal subscriptions in the browser.",'<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>',"Sub-Millisecond","Dual-Backend SSR & Instant Hydration"),n.H("ForEachNode uses active key registries to reuse existing DOM elements on list updates, preserving input focus, scroll positions, and native CSS transitions during high-throughput mutations.",'<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16"/>',"Zero DOM Tear-down","Keyed DOM List Reconciliation"),n.H("Consume any of the 2.5M+ NPM packages surgically. The Bloom CLI runs Bun to extract ESM bundles into web/vendor/ and manages browser import maps automatically with CDN fallback.",'<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>',"NPM Native","Bun ESM Toolchain Orchestration"),n.H("Organize pages naturally in lib/routes/ with automatic parameter parsing ([slug].dart), nested layout cascades (_layout.dart), and dedicated 404 boundaries (_error.dart).",'<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6 3V7m6 10l4.553 2.276A1 1 0 0021 18.382V7.618a1 1 0 00-.553-.894L15 4m0 13V4m0 0L9 7"/>',"Standardized DX","Next.js File-Based Page Routing")],l),"grid grid-cols-1 md:grid-cols-2 gap-6")],l),"py-20 px-6 max-w-7xl mx-auto"),new A.ct(o).v()],l)),new A.bp("footer",q,"w-full border-t border-[#1E1E24] bg-[#060608] py-12 px-6",q,q,q,A.c([A.h(A.c([A.h(A.c([A.a("font-semibold text-zinc-300 font-mono","Bloom JS Native"),A.a("text-zinc-600","\u2022"),A.a(q,"MIT Open Source Framework")],l),"flex items-center gap-4"),A.h(A.c([A.a("w-2 h-2 rounded-full bg-emerald-500 animate-pulse",q),A.a(q,"Runtime Status: Nominal (<1ms SSR)")],l),"inline-flex items-center gap-2 px-3 py-1 rounded-full bg-[#101014] border border-[#1E1E24] text-xs font-mono text-emerald-400"),A.h(A.c([A.ae(B.a,p,"https://github.com/Chidi09/Bloom","GitHub"),A.ae(B.a,p,"https://github.com/Chidi09/Bloom/tree/main/packages/bloom_js_native","Docs")],l),"flex items-center gap-6")],l),"max-w-7xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-6 text-sm text-zinc-500")],l)),new A.y(new A.e0(o))],l),"min-h-screen bg-[#09090B] text-zinc-100 flex flex-col justify-between selection:bg-indigo-600 selection:text-white relative")
l=v.G
s=l.document.querySelector("#app")
if(s==null)A.e2(A.hf('Bloom mount: selector "#app" matched no element.'))
A.iW(k,s)
r=l.document.getElementById("three-hero-canvas")
if(r!=null)new A.d2(r).b0()},
e0:function e0(a){this.a=a},
d2:function d2(a){this.a=a
this.b=!1},
d3:function d3(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
d4:function d4(a,b,c){this.a=a
this.b=b
this.c=c},
hd(){var s,r,q=A.ac("main.dart",t.N),p=t.S,o=A.ac(24,p),n=A.ac(60,p),m=A.ac(0.12,t.i),l=J.eJ(24,p)
for(s=0;s<24;s=r){r=s+1
l[s]=r}p=t.y
p=new A.cW(q,o,n,m,A.ac(l,t.L),A.ac(!1,p),A.ac(null,t.u),A.ac(!1,p))
p.aT()
return p},
cW:function cW(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
d_:function d_(a){this.a=a},
cZ:function cZ(a,b){this.a=a
this.b=b},
cY:function cY(a){this.a=a},
cX:function cX(){},
el(){var s,r,q,p,o,n,m=$.L
if(m>1){$.L=m-1
return}s=null
r=!1
while(m=$.dG,m!=null){q=m
$.dG=null
$.dK=$.dK+1
while(q!=null){o=q.f
q.f=null
q.r&=4294967293
if((q.r&8)===0&&A.ip(q))try{q.a5()}catch(n){p=A.ad(n)
if(!r){s=p
r=!0}}q=o}}$.dK=0
$.L=$.L-1
if(r)throw A.e(s)},
iL(a){var s,r=$.dN+1
$.dN=r
s=new A.bn(a,null,r,A.cM(t.M))
s.aC(a,null)
return s.gaX()},
he(a,b,c,d){var s=$.dN+1
$.dN=s
s=new A.aT(a,new A.d0(d),!1,c,s,A.cM(t.M),d.i("aT<0>"))
s.z=a
return s},
ac(a,b){return A.he(a,!1,null,b)},
hH(a){var s,r,q,p=null,o=$.a3
if(o==null)return p
s=a.f
if(s==null||s.d!==o){r=o.e
s=new A.dt(a,r,p,o,p,p,0,s)
if(r!=null)r.c=s
a.f=o.e=s
if((o.r&32)!==0){o=a.r
if(o!==s){s.f=o
if(o!=null)o.e=s
a.r=s}}return s}else if(s.r===-1){s.r=0
r=s.c
if(r!=null){r.b=s.b
q=s.b
if(q!=null)q.c=r
r=o.e
s.b=r
s.c=null
o.e=r.c=s}return s}return p},
ip(a){var s,r,q
for(s=a.e;s!=null;s=s.c){r=s.a.e
q=s.r
if(r!==q)return!0}return!1},
iq(a){var s,r,q,p
for(s=a.e;s!=null;s=p){r=s.a
q=r.f
if(q!=null)s.w=q
r.f=s
s.r=-1
p=s.c
if(p==null){a.e=s
break}}},
hW(a){var s,r,q,p,o=a.e
for(s=null;o!=null;o=r){r=o.b
if(o.r===-1){o.a.a1(o)
if(r!=null)r.c=o.c
q=o.c
if(q!=null)q.b=r}else s=o
q=o.a
p=o.w
q.f=p
if(p!=null)o.w=null}a.e=s},
f9(a){var s,r,q=a.d
a.d=null
if(q!=null){$.L=$.L+1
s=$.a3
$.a3=null
try{q.$0()}catch(r){a.r=(a.r&=4294967294)|8
A.ek(a)
throw r}finally{$.a3=s
A.el()}}},
ek(a){var s
for(s=a.e;s!=null;s=s.c)s.a.a1(s)
a.e=a.a=null
A.f9(a)},
bn:function bn(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.f=_.e=_.d=null
_.r=32
_.w=d
_.x=!1},
cx:function cx(a,b){this.a=a
this.b=b},
aR:function aR(){},
aT:function aT(a,b,c,d,e,f,g){var _=this
_.y=!1
_.z=$
_.Q=a
_.as=b
_.a=c
_.b=!1
_.c=d
_.d=e
_.e=0
_.r=_.f=null
_.w=f
_.$ti=g},
d0:function d0(a){this.a=a},
dt:function dt(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
bZ:function bZ(){},
c_:function c_(a){this.a=a},
az:function az(){},
fw(a){return v.mangledGlobalNames[a]},
iX(a){if(typeof dartPrint=="function"){dartPrint(a)
return}if(typeof console=="object"&&typeof console.log!="undefined"){console.log(a)
return}if(typeof print=="function"){print(a)
return}throw"Unable to print message: "+String(a)},
iZ(a){throw A.v(new A.aK("Field '"+a+"' has been assigned during initialization."),new Error())},
cf(){throw A.v(A.h3(""),new Error())},
fV(a,b){var s,r,q
try{r=t.N
s=A.cd(A.dZ(A.Z(["particleCount",60,"spread",70,"origin",A.Z(["x",a,"y",b],r,t.i),"colors",A.c(["#6366F1","#8B5CF6","#3B82F6","#10B981"],t.s),"disableForReducedMotion",!0],r,t.z)))
v.G.confetti(s)}catch(q){}}},B={}
var w=[A,J,B]
var $={}
A.ea.prototype={}
J.bu.prototype={
B(a,b){return a===b},
gn(a){return A.bT(a)},
h(a){return"Instance of '"+A.bU(a)+"'"},
gm(a){return A.a8(A.em(this))}}
J.bw.prototype={
h(a){return String(a)},
gn(a){return a?519018:218159},
gm(a){return A.a8(t.y)},
$ij:1}
J.aF.prototype={
B(a,b){return null==b},
h(a){return"null"},
gn(a){return 0},
$ij:1,
$iw:1}
J.aI.prototype={$ip:1}
J.P.prototype={
gn(a){return 0},
h(a){return String(a)}}
J.bR.prototype={}
J.aV.prototype={}
J.O.prototype={
h(a){var s=a[$.fy()]
if(s==null)s=a[$.ew()]
if(s==null)return this.aA(a)
return"JavaScript function for "+J.bf(s)},
$iW:1}
J.aH.prototype={
gn(a){return 0},
h(a){return String(a)}}
J.aJ.prototype={
gn(a){return 0},
h(a){return String(a)}}
J.t.prototype={
E(a,b){a.$flags&1&&A.fv(a,29)
a.push(b)},
af(a,b){var s
a.$flags&1&&A.fv(a,"addAll",2)
if(Array.isArray(b)){this.aI(a,b)
return}for(s=J.e3(b);s.k();)a.push(s.gl())},
aI(a,b){var s,r=b.length
if(r===0)return
if(a===b)throw A.e(A.N(a))
for(s=0;s<r;++s)a.push(b[s])},
F(a,b,c){return new A.I(a,b,A.dE(a).i("@<1>").t(c).i("I<1,2>"))},
M(a,b){return a[b]},
h(a){return A.e9(a,"[","]")},
gp(a){return new J.bh(a,a.length,A.dE(a).i("bh<1>"))},
gn(a){return A.bT(a)},
gu(a){return a.length},
$if:1,
$id:1,
$in:1}
J.bv.prototype={
bi(a){var s,r,q
if(!Array.isArray(a))return null
s=a.$flags|0
if((s&4)!==0)r="const, "
else if((s&2)!==0)r="unmodifiable, "
else r=(s&1)!==0?"fixed, ":""
q="Instance of '"+A.bU(a)+"'"
if(r==="")return q
return q+" ("+r+"length: "+a.length+")"}}
J.cK.prototype={}
J.bh.prototype={
gl(){var s=this.d
return s==null?this.$ti.c.a(s):s},
k(){var s,r=this,q=r.a,p=q.length
if(r.b!==p)throw A.e(A.be(q))
s=r.c
if(s>=p){r.d=null
return!1}r.d=q[s]
r.c=s+1
return!0}}
J.aG.prototype={
U(a,b){var s
if(a<b)return-1
else if(a>b)return 1
else if(a===b){if(a===0){s=B.b.gN(b)
if(this.gN(a)===s)return 0
if(this.gN(a))return-1
return 1}return 0}else if(isNaN(a)){if(isNaN(b))return 0
return 1}else return-1},
gN(a){return a===0?1/a<0:a<0},
aZ(a){var s,r
if(a>=0){if(a<=2147483647)return a|0}else if(a>=-2147483648){s=a|0
return a===s?s:s-1}r=Math.floor(a)
if(isFinite(r))return r
throw A.e(A.aX(""+a+".floor()"))},
ah(a,b,c){if(B.b.U(b,c)>0)throw A.e(A.iE(b))
if(this.U(a,b)<0)return b
if(this.U(a,c)>0)return c
return a},
bg(a,b){var s
if(b>20)throw A.e(A.cU(b,0,20,"fractionDigits",null))
s=a.toFixed(b)
if(a===0&&this.gN(a))return"-"+s
return s},
h(a){if(a===0&&1/a<0)return"-0.0"
else return""+a},
gn(a){var s,r,q,p,o=a|0
if(a===o)return o&536870911
s=Math.abs(a)
r=Math.log(s)/0.6931471805599453|0
q=Math.pow(2,r)
p=s<1?s/q:q/s
return((p*9007199254740992|0)+(p*3542243181176521|0))*599197+r*1259&536870911},
a0(a,b){var s=a%b
if(s===0)return 0
if(s>0)return s
return s+b},
aB(a,b){if((a|0)===a)if(b>=1)return a/b|0
return this.ae(a,b)},
ad(a,b){return(a|0)===a?a/b|0:this.ae(a,b)},
ae(a,b){var s=a/b
if(s>=-2147483648&&s<=2147483647)return s|0
if(s>0){if(s!==1/0)return Math.floor(s)}else if(s>-1/0)return Math.ceil(s)
throw A.e(A.aX("Result of truncating division is "+A.o(s)+": "+A.o(a)+" ~/ "+b))},
aR(a,b){var s
if(a>0)s=this.aQ(a,b)
else{s=b>31?31:b
s=a>>s>>>0}return s},
aQ(a,b){return b>31?0:a>>>b},
gm(a){return A.a8(t.H)},
$ik:1}
J.aE.prototype={
gm(a){return A.a8(t.S)},
$ij:1,
$ib:1}
J.bx.prototype={
gm(a){return A.a8(t.i)},
$ij:1}
J.aj.prototype={
az(a,b,c){return a.substring(b,A.hb(b,c,a.length))},
bh(a){var s,r,q,p=a.trim(),o=p.length
if(o===0)return p
if(p.charCodeAt(0)===133){s=J.h1(p,1)
if(s===o)return""}else s=0
r=o-1
q=p.charCodeAt(r)===133?J.h2(p,r):o
if(s===0&&q===o)return p
return p.substring(s,q)},
aq(a,b){var s,r
if(0>=b)return""
if(b===1||a.length===0)return a
if(b!==b>>>0)throw A.e(B.t)
for(s=a,r="";;){if((b&1)===1)r=s+r
b=b>>>1
if(b===0)break
s+=s}return r},
b4(a,b,c){var s=b-a.length
if(s<=0)return a
return this.aq(c,s)+a},
h(a){return a},
gn(a){var s,r,q
for(s=a.length,r=0,q=0;q<s;++q){r=r+a.charCodeAt(q)&536870911
r=r+((r&524287)<<10)&536870911
r^=r>>6}r=r+((r&67108863)<<3)&536870911
r^=r>>11
return r+((r&16383)<<15)&536870911},
gm(a){return A.a8(t.N)},
$ij:1,
$iQ:1}
A.aK.prototype={
h(a){return"LateInitializationError: "+this.a}}
A.f.prototype={}
A.E.prototype={
gp(a){return new A.ak(this,this.gu(0),this.$ti.i("ak<E.E>"))},
F(a,b,c){return new A.I(this,b,this.$ti.i("@<E.E>").t(c).i("I<1,2>"))}}
A.ak.prototype={
gl(){var s=this.d
return s==null?this.$ti.c.a(s):s},
k(){var s,r=this,q=r.a,p=J.fp(q),o=p.gu(q)
if(r.b!==o)throw A.e(A.N(q))
s=r.c
if(s>=o){r.d=null
return!1}r.d=p.M(q,s);++r.c
return!0}}
A.a1.prototype={
gp(a){var s=this.a
return new A.bD(s.gp(s),this.b,A.a4(this).i("bD<1,2>"))}}
A.U.prototype={$if:1}
A.bD.prototype={
k(){var s=this,r=s.b
if(r.k()){s.a=s.c.$1(r.gl())
return!0}s.a=null
return!1},
gl(){var s=this.a
return s==null?this.$ti.y[1].a(s):s}}
A.I.prototype={
gu(a){return J.fM(this.a)},
M(a,b){return this.b.$1(J.fL(this.a,b))}}
A.aB.prototype={
su(a,b){throw A.e(A.aX("Cannot change the length of a fixed-length list"))},
E(a,b){throw A.e(A.aX("Cannot add to a fixed-length list"))}}
A.cR.prototype={
$0(){return B.k.aZ(1000*this.a.now())},
$S:5}
A.aS.prototype={}
A.d6.prototype={
q(a){var s,r,q=this,p=new RegExp(q.a).exec(a)
if(p==null)return null
s=Object.create(null)
r=q.b
if(r!==-1)s.arguments=p[r+1]
r=q.c
if(r!==-1)s.argumentsExpr=p[r+1]
r=q.d
if(r!==-1)s.expr=p[r+1]
r=q.e
if(r!==-1)s.method=p[r+1]
r=q.f
if(r!==-1)s.receiver=p[r+1]
return s}}
A.aQ.prototype={
h(a){return"Null check operator used on a null value"}}
A.by.prototype={
h(a){var s,r=this,q="NoSuchMethodError: method not found: '",p=r.b
if(p==null)return"NoSuchMethodError: "+r.a
s=r.c
if(s==null)return q+p+"' ("+r.a+")"
return q+p+"' on '"+s+"' ("+r.a+")"}}
A.c5.prototype={
h(a){var s=this.a
return s.length===0?"Error":"Error: "+s}}
A.cQ.prototype={
h(a){return"Throw of null ('"+(this.a===null?"null":"undefined")+"' from JavaScript)"}}
A.bo.prototype={}
A.b6.prototype={
h(a){var s,r=this.b
if(r!=null)return r
r=this.a
s=r!==null&&typeof r==="object"?r.stack:null
return this.b=s==null?"":s},
$iap:1}
A.M.prototype={
h(a){var s=this.constructor,r=s==null?null:s.name
return"Closure '"+A.fx(r==null?"unknown":r)+"'"},
$iW:1,
gbj(){return this},
$C:"$1",
$R:1,
$D:null}
A.bk.prototype={$C:"$0",$R:0}
A.bl.prototype={$C:"$2",$R:2}
A.c3.prototype={}
A.c1.prototype={
h(a){var s=this.$static_name
if(s==null)return"Closure of unknown static method"
return"Closure '"+A.fx(s)+"'"}}
A.ag.prototype={
B(a,b){if(b==null)return!1
if(this===b)return!0
if(!(b instanceof A.ag))return!1
return this.$_target===b.$_target&&this.a===b.a},
gn(a){return(A.ev(this.a)^A.bT(this.$_target))>>>0},
h(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.bU(this.a)+"'")}}
A.bX.prototype={
h(a){return"RuntimeError: "+this.a}}
A.X.prototype={
gW(){return new A.aL(this,A.a4(this).i("aL<1>"))},
C(a,b){var s,r,q,p,o=null
if(typeof b=="string"){s=this.b
if(s==null)return o
r=s[b]
q=r==null?o:r.b
return q}else if(typeof b=="number"&&(b&0x3fffffff)===b){p=this.c
if(p==null)return o
r=p[b]
q=r==null?o:r.b
return q}else return this.b1(b)},
b1(a){var s,r,q=this.d
if(q==null)return null
s=this.aF(q,a)
r=this.al(s,a)
if(r<0)return null
return s[r].b},
A(a,b,c){var s,r,q=this
if(typeof b=="string"){s=q.b
q.a2(s==null?q.b=q.R():s,b,c)}else if(typeof b=="number"&&(b&0x3fffffff)===b){r=q.c
q.a2(r==null?q.c=q.R():r,b,c)}else q.b2(b,c)},
b2(a,b){var s,r,q,p=this,o=p.d
if(o==null)o=p.d=p.R()
s=p.ak(a)
r=o[s]
if(r==null)o[s]=[p.O(a,b)]
else{q=p.al(r,a)
if(q>=0)r[q].b=b
else r.push(p.O(a,b))}},
V(a,b){var s=this,r=s.e,q=s.r
while(r!=null){b.$2(r.a,r.b)
if(q!==s.r)throw A.e(A.N(s))
r=r.c}},
a2(a,b,c){var s=a[b]
if(s==null)a[b]=this.O(b,c)
else s.b=c},
aG(){this.r=this.r+1&1073741823},
O(a,b){var s,r=this,q=new A.cL(a,b)
if(r.e==null)r.e=r.f=q
else{s=r.f
s.toString
q.d=s
r.f=s.c=q}++r.a
r.aG()
return q},
ak(a){return J.cg(a)&1073741823},
aF(a,b){return a[this.ak(b)]},
al(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.ez(a[r].a,b))return r
return-1},
h(a){return A.eM(this)},
R(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s}}
A.cL.prototype={}
A.aL.prototype={
gp(a){var s=this.a
return new A.bA(s,s.r,s.e)}}
A.bA.prototype={
gl(){return this.d},
k(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.e(A.N(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=s.a
r.c=s.c
return!0}}}
A.Y.prototype={
gp(a){var s=this.a
return new A.bz(s,s.r,s.e,this.$ti.i("bz<1,2>"))}}
A.bz.prototype={
gl(){var s=this.d
s.toString
return s},
k(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.e(A.N(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=new A.a0(s.a,s.b,r.$ti.i("a0<1,2>"))
r.c=s.c
return!0}}}
A.dV.prototype={
$1(a){return this.a(a)},
$S:9}
A.dW.prototype={
$2(a,b){return this.a(a,b)},
$S:10}
A.dX.prototype={
$1(a){return this.a(a)},
$S:11}
A.al.prototype={
gm(a){return B.B},
$ij:1,
$ie6:1}
A.aO.prototype={}
A.bE.prototype={
gm(a){return B.C},
$ij:1,
$ie7:1}
A.am.prototype={
gu(a){return a.length},
$iz:1}
A.aM.prototype={$if:1,$id:1,$in:1}
A.aN.prototype={$if:1,$id:1,$in:1}
A.bF.prototype={
gm(a){return B.D},
$ij:1,
$icA:1}
A.bG.prototype={
gm(a){return B.E},
$ij:1,
$icB:1}
A.bH.prototype={
gm(a){return B.F},
$ij:1,
$icH:1}
A.bI.prototype={
gm(a){return B.G},
$ij:1,
$icI:1}
A.bJ.prototype={
gm(a){return B.H},
$ij:1,
$icJ:1}
A.bK.prototype={
gm(a){return B.I},
$ij:1,
$id8:1}
A.bL.prototype={
gm(a){return B.J},
$ij:1,
$id9:1}
A.aP.prototype={
gm(a){return B.K},
gu(a){return a.length},
$ij:1,
$ida:1}
A.bM.prototype={
gm(a){return B.L},
gu(a){return a.length},
$ij:1,
$idb:1}
A.b1.prototype={}
A.b2.prototype={}
A.b3.prototype={}
A.b4.prototype={}
A.C.prototype={
i(a){return A.dB(v.typeUniverse,this,a)},
t(a){return A.hE(v.typeUniverse,this,a)}}
A.c8.prototype={}
A.dz.prototype={
h(a){return A.A(this.a,null)}}
A.c7.prototype={
h(a){return this.a}}
A.b8.prototype={$iJ:1}
A.dd.prototype={
$1(a){var s=this.a,r=s.a
s.a=null
r.$0()},
$S:6}
A.dc.prototype={
$1(a){var s,r
this.a.a=a
s=this.b
r=this.c
s.firstChild?s.removeChild(r):s.appendChild(r)},
$S:12}
A.de.prototype={
$0(){this.a.$0()},
$S:1}
A.df.prototype={
$0(){this.a.$0()},
$S:1}
A.b7.prototype={
aD(a,b){if(self.setTimeout!=null)self.setTimeout(A.ce(new A.dy(this,b),0),a)
else throw A.e(A.aX("`setTimeout()` not found."))},
aE(a,b){if(self.setTimeout!=null)self.setInterval(A.ce(new A.dx(this,a,Date.now(),b),0),a)
else throw A.e(A.aX("Periodic timer."))},
$id5:1}
A.dy.prototype={
$0(){this.a.c=1
this.b.$0()},
$S:0}
A.dx.prototype={
$0(){var s,r=this,q=r.a,p=q.c+1,o=r.b
if(o>0){s=Date.now()-r.c
if(s>(p+1)*o)p=B.b.aB(s,o)}q.c=p
r.d.$1(q)},
$S:1}
A.H.prototype={
h(a){return A.o(this.a)},
$im:1,
gG(){return this.b}}
A.cD.prototype={
$0(){var s,r,q,p,o,n,m=this,l=m.a
if(l==null){m.c.a(null)
m.b.a6(null)}else{s=null
try{s=l.$0()}catch(p){r=A.ad(p)
q=A.aa(p)
l=r
o=q
n=A.i4(l,o)
l=new A.H(l,o)
m.b.P(l)
return}m.b.a6(s)}},
$S:0}
A.c9.prototype={
b3(a){if((this.c&15)!==6)return!0
return this.b.b.Y(this.d,a.a)},
b_(a){var s,r=this.e,q=null,p=a.a,o=this.b.b
if(t.C.b(r))q=o.b9(r,p,a.b)
else q=o.Y(r,p)
try{p=q
return p}catch(s){if(t.e.b(A.ad(s))){if((this.c&1)!==0)throw A.e(A.ax("The error handler of Future.then must return a value of the returned future's type","onError"))
throw A.e(A.ax("The error handler of Future.catchError must return a value of the future's type","onError"))}else throw s}}}
A.D.prototype={
bf(a,b,c){var s,r=$.r
if(r===B.c){if(!t.C.b(b)&&!t.v.b(b))throw A.e(A.eB(b,"onError",u.c))}else b=A.is(b,r)
s=new A.D(r,c.i("D<0>"))
this.a4(new A.c9(s,3,a,b,this.$ti.i("@<1>").t(c).i("c9<1,2>")))
return s},
aP(a){this.a=this.a&1|16
this.c=a},
I(a){this.a=a.a&30|this.a&1
this.c=a.c},
a4(a){var s=this,r=s.a
if(r<=3){a.a=s.c
s.c=a}else{if((r&4)!==0){r=s.c
if((r.a&24)===0){r.a4(a)
return}s.I(r)}A.dR(null,null,s.b,new A.dh(s,a))}},
ac(a){var s,r,q,p,o,n=this,m={}
m.a=a
if(a==null)return
s=n.a
if(s<=3){r=n.c
n.c=a
if(r!=null){q=a.a
for(p=a;q!=null;p=q,q=o)o=q.a
p.a=r}}else{if((s&4)!==0){s=n.c
if((s.a&24)===0){s.ac(a)
return}n.I(s)}m.a=n.L(a)
A.dR(null,null,n.b,new A.dk(m,n))}},
K(){var s=this.c
this.c=null
return this.L(s)},
L(a){var s,r,q
for(s=a,r=null;s!=null;r=s,s=q){q=s.a
s.a=r}return r},
a6(a){var s,r=this
if(r.$ti.i("aD<1>").b(a))A.eg(a,r,!0)
else{s=r.K()
r.a=8
r.c=a
A.aq(r,s)}},
aK(a){var s,r,q=this
if((a.a&16)!==0){s=q.b===a.b
s=!(s||s)}else s=!1
if(s)return
r=q.K()
q.I(a)
A.aq(q,r)},
P(a){var s=this.K()
this.aP(a)
A.aq(this,s)},
aJ(a){this.a^=2
A.dR(null,null,this.b,new A.di(this,a))},
$iaD:1}
A.dh.prototype={
$0(){A.aq(this.a,this.b)},
$S:0}
A.dk.prototype={
$0(){A.aq(this.b,this.a.a)},
$S:0}
A.dj.prototype={
$0(){A.eg(this.a.a,this.b,!0)},
$S:0}
A.di.prototype={
$0(){this.a.P(this.b)},
$S:0}
A.dn.prototype={
$0(){var s,r,q,p,o,n,m,l,k=this,j=null
try{q=k.a.a
j=q.b.b.b7(q.d)}catch(p){s=A.ad(p)
r=A.aa(p)
if(k.c&&k.b.a.c.a===s){q=k.a
q.c=k.b.a.c}else{q=s
o=r
if(o==null)o=A.e5(q)
n=k.a
n.c=new A.H(q,o)
q=n}q.b=!0
return}if(j instanceof A.D&&(j.a&24)!==0){if((j.a&16)!==0){q=k.a
q.c=j.c
q.b=!0}return}if(j instanceof A.D){m=k.b.a
l=new A.D(m.b,m.$ti)
j.bf(new A.dp(l,m),new A.dq(l),t.b9)
q=k.a
q.c=l
q.b=!1}},
$S:0}
A.dp.prototype={
$1(a){this.a.aK(this.b)},
$S:6}
A.dq.prototype={
$2(a,b){this.a.P(new A.H(a,b))},
$S:13}
A.dm.prototype={
$0(){var s,r,q,p,o,n
try{q=this.a
p=q.a
q.c=p.b.b.Y(p.d,this.b)}catch(o){s=A.ad(o)
r=A.aa(o)
q=s
p=r
if(p==null)p=A.e5(q)
n=this.a
n.c=new A.H(q,p)
n.b=!0}},
$S:0}
A.dl.prototype={
$0(){var s,r,q,p,o,n,m,l=this
try{s=l.a.a.c
p=l.b
if(p.a.b3(s)&&p.a.e!=null){p.c=p.a.b_(s)
p.b=!1}}catch(o){r=A.ad(o)
q=A.aa(o)
p=l.a.a.c
if(p.a===r){n=l.b
n.c=p
p=n}else{p=r
n=q
if(n==null)n=A.e5(p)
m=l.b
m.c=new A.H(p,n)
p=m}p.b=!0}},
$S:0}
A.c6.prototype={}
A.dD.prototype={}
A.du.prototype={
bb(a){var s,r,q
try{if(B.c===$.r){a.$0()
return}A.fh(null,null,this,a)}catch(q){s=A.ad(q)
r=A.aa(q)
A.dP(s,r)}},
bd(a,b){var s,r,q
try{if(B.c===$.r){a.$1(b)
return}A.fi(null,null,this,a,b)}catch(q){s=A.ad(q)
r=A.aa(q)
A.dP(s,r)}},
be(a,b){return this.bd(a,b,t.z)},
ag(a){return new A.dv(this,a)},
aV(a,b){return new A.dw(this,a,b)},
b8(a){if($.r===B.c)return a.$0()
return A.fh(null,null,this,a)},
b7(a){return this.b8(a,t.z)},
bc(a,b){if($.r===B.c)return a.$1(b)
return A.fi(null,null,this,a,b)},
Y(a,b){var s=t.z
return this.bc(a,b,s,s)},
ba(a,b,c){if($.r===B.c)return a.$2(b,c)
return A.it(null,null,this,a,b,c)},
b9(a,b,c){var s=t.z
return this.ba(a,b,c,s,s,s)},
b6(a){return a},
b5(a){var s=t.z
return this.b6(a,s,s,s)}}
A.dv.prototype={
$0(){return this.a.bb(this.b)},
$S:0}
A.dw.prototype={
$1(a){return this.a.be(this.b,a)},
$S(){return this.c.i("~(0)")}}
A.dQ.prototype={
$0(){A.fX(this.a,this.b)},
$S:0}
A.aY.prototype={
gW(){return new A.aZ(this,this.$ti.i("aZ<1>"))},
aW(a){var s,r
if(typeof a=="string"&&a!=="__proto__"){s=this.b
return s==null?!1:s[a]!=null}else if(typeof a=="number"&&(a&1073741823)===a){r=this.c
return r==null?!1:r[a]!=null}else return this.aL(a)},
aL(a){var s=this.d
if(s==null)return!1
return this.D(this.aa(s,a),a)>=0},
C(a,b){var s,r,q
if(typeof b=="string"&&b!=="__proto__"){s=this.b
r=s==null?null:A.eV(s,b)
return r}else if(typeof b=="number"&&(b&1073741823)===b){q=this.c
r=q==null?null:A.eV(q,b)
return r}else return this.aM(b)},
aM(a){var s,r,q=this.d
if(q==null)return null
s=this.aa(q,a)
r=this.D(s,a)
return r<0?null:s[r+1]},
A(a,b,c){var s,r,q,p=this,o=p.d
if(o==null)o=p.d=A.hm()
s=A.ev(b)&1073741823
r=o[s]
if(r==null){A.eW(o,s,[b,c]);++p.a
p.e=null}else{q=p.D(r,b)
if(q>=0)r[q+1]=c
else{r.push(b,c);++p.a
p.e=null}}},
V(a,b){var s,r,q,p,o,n=this,m=n.a7()
for(s=m.length,r=n.$ti.y[1],q=0;q<s;++q){p=m[q]
o=n.C(0,p)
b.$2(p,o==null?r.a(o):o)
if(m!==n.e)throw A.e(A.N(n))}},
a7(){var s,r,q,p,o,n,m,l,k,j,i=this,h=i.e
if(h!=null)return h
h=A.h4(i.a,null,!1,t.z)
s=i.b
r=0
if(s!=null){q=Object.getOwnPropertyNames(s)
p=q.length
for(o=0;o<p;++o){h[r]=q[o];++r}}n=i.c
if(n!=null){q=Object.getOwnPropertyNames(n)
p=q.length
for(o=0;o<p;++o){h[r]=+q[o];++r}}m=i.d
if(m!=null){q=Object.getOwnPropertyNames(m)
p=q.length
for(o=0;o<p;++o){l=m[q[o]]
k=l.length
for(j=0;j<k;j+=2){h[r]=l[j];++r}}}return i.e=h},
aa(a,b){return a[A.ev(b)&1073741823]}}
A.b_.prototype={
D(a,b){var s,r,q
if(a==null)return-1
s=a.length
for(r=0;r<s;r+=2){q=a[r]
if(q==null?b==null:q===b)return r}return-1}}
A.aZ.prototype={
gp(a){var s=this.a
return new A.ca(s,s.a7(),this.$ti.i("ca<1>"))}}
A.ca.prototype={
gl(){var s=this.d
return s==null?this.$ti.c.a(s):s},
k(){var s=this,r=s.b,q=s.c,p=s.a
if(r!==p.e)throw A.e(A.N(p))
else if(q>=r.length){s.d=null
return!1}else{s.d=r[q]
s.c=q+1
return!0}}}
A.b0.prototype={
gp(a){var s=this,r=new A.ar(s,s.r,s.$ti.i("ar<1>"))
r.c=s.e
return r},
E(a,b){var s,r,q=this
if(typeof b=="string"&&b!=="__proto__"){s=q.b
return q.a3(s==null?q.b=A.eh():s,b)}else if(typeof b=="number"&&(b&1073741823)===b){r=q.c
return q.a3(r==null?q.c=A.eh():r,b)}else return q.aH(b)},
aH(a){var s,r,q=this,p=q.d
if(p==null)p=q.d=A.eh()
s=J.cg(a)&1073741823
r=p[s]
if(r==null)p[s]=[q.S(a)]
else{if(q.D(r,a)>=0)return!1
r.push(q.S(a))}return!0},
a3(a,b){if(a[b]!=null)return!1
a[b]=this.S(b)
return!0},
ab(){this.r=this.r+1&1073741823},
S(a){var s,r=this,q=new A.ds(a)
if(r.e==null)r.e=r.f=q
else{s=r.f
s.toString
q.c=s
r.f=s.b=q}++r.a
r.ab()
return q},
D(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.ez(a[r].a,b))return r
return-1}}
A.ds.prototype={}
A.ar.prototype={
gl(){var s=this.d
return s==null?this.$ti.c.a(s):s},
k(){var s=this,r=s.c,q=s.a
if(s.b!==q.r)throw A.e(A.N(q))
else if(r==null){s.d=null
return!1}else{s.d=r.a
s.c=r.b
return!0}}}
A.q.prototype={
gp(a){return new A.ak(a,a.length,A.av(a).i("ak<q.E>"))},
M(a,b){return a[b]},
F(a,b,c){return new A.I(a,b,A.av(a).i("@<q.E>").t(c).i("I<1,2>"))},
E(a,b){var s=a.length
this.su(a,s+1)
a[s]=b},
h(a){return A.e9(a,"[","]")}}
A.a_.prototype={
V(a,b){var s,r,q,p
for(s=this.gW(),s=s.gp(s),r=A.a4(this).y[1];s.k();){q=s.gl()
p=this.C(0,q)
b.$2(q,p==null?r.a(p):p)}},
h(a){return A.eM(this)}}
A.cN.prototype={
$2(a,b){var s,r=this.a
if(!r.a)this.b.a+=", "
r.a=!1
r=this.b
s=A.o(a)
r.a=(r.a+=s)+": "
s=A.o(b)
r.a+=s},
$S:14}
A.an.prototype={
F(a,b,c){return new A.U(this,b,this.$ti.i("@<1>").t(c).i("U<1,2>"))},
h(a){return A.e9(this,"{","}")},
$if:1,
$id:1}
A.b5.prototype={}
A.ai.prototype={
B(a,b){if(b==null)return!1
return b instanceof A.ai&&this.a===b.a},
gn(a){return B.b.gn(this.a)},
h(a){var s,r,q,p=this.a,o=p%36e8,n=B.b.ad(o,6e7)
o%=6e7
s=n<10?"0":""
r=B.b.ad(o,1e6)
q=r<10?"0":""
return""+(p/36e8|0)+":"+s+n+":"+q+r+"."+B.d.b4(B.b.h(o%1e6),6,"0")}}
A.m.prototype={
gG(){return A.h7(this)}}
A.bi.prototype={
h(a){var s=this.a
if(s!=null)return"Assertion failed: "+A.cy(s)
return"Assertion failed"}}
A.J.prototype={}
A.G.prototype={
ga9(){return"Invalid argument"+(!this.a?"(s)":"")},
ga8(){return""},
h(a){var s=this,r=s.c,q=r==null?"":" ("+r+")",p=s.d,o=p==null?"":": "+p,n=s.ga9()+q+o
if(!s.a)return n
return n+s.ga8()+": "+A.cy(s.gam())},
gam(){return this.b}}
A.bV.prototype={
gam(){return this.b},
ga9(){return"RangeError"},
ga8(){var s,r=this.e,q=this.f
if(r==null)s=q!=null?": Not less than or equal to "+A.o(q):""
else if(q==null)s=": Not greater than or equal to "+A.o(r)
else if(q>r)s=": Not in inclusive range "+A.o(r)+".."+A.o(q)
else s=q<r?": Valid value range is empty":": Only valid value is "+A.o(r)
return s}}
A.aW.prototype={
h(a){return"Unsupported operation: "+this.a}}
A.c4.prototype={
h(a){return"UnimplementedError: "+this.a}}
A.c0.prototype={
h(a){return"Bad state: "+this.a}}
A.bm.prototype={
h(a){var s=this.a
if(s==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.cy(s)+"."}}
A.bO.prototype={
h(a){return"Out of Memory"},
gG(){return null},
$im:1}
A.aU.prototype={
h(a){return"Stack Overflow"},
gG(){return null},
$im:1}
A.dg.prototype={
h(a){return"Exception: "+this.a}}
A.cC.prototype={
h(a){var s=this.a,r=""!==s?"FormatException: "+s:"FormatException",q=this.b
if(q.length>78)q=B.d.az(q,0,75)+"..."
return r+"\n"+q}}
A.d.prototype={
F(a,b,c){return A.h5(this,b,A.a4(this).i("d.E"),c)},
h(a){return A.fY(this,"(",")")}}
A.a0.prototype={
h(a){return"MapEntry("+A.o(this.a)+": "+A.o(this.b)+")"}}
A.w.prototype={
gn(a){return A.i.prototype.gn.call(this,0)},
h(a){return"null"}}
A.i.prototype={$ii:1,
B(a,b){return this===b},
gn(a){return A.bT(this)},
h(a){return"Instance of '"+A.bU(this)+"'"},
gm(a){return A.fq(this)},
toString(){return this.h(this)}}
A.cc.prototype={
h(a){return""},
$iap:1}
A.d1.prototype={
gaY(){var s,r=this.b
if(r==null)r=$.cT.$0()
s=r-this.a
if($.ex()===1e6)return s
return s*1000}}
A.c2.prototype={
h(a){var s=this.a
return s.charCodeAt(0)==0?s:s}}
A.e_.prototype={
$1(a){var s,r,q,p
if(A.fg(a))return a
s=this.a
if(s.aW(a))return s.C(0,a)
if(a instanceof A.a_){r={}
s.A(0,a,r)
for(s=a.gW(),s=s.gp(s);s.k();){q=s.gl()
r[q]=this.$1(a.C(0,q))}return r}else if(t.a.b(a)){p=[]
s.A(0,a,p)
B.j.af(p,J.e4(a,this,t.z))
return p}else return a},
$S:15}
A.af.prototype={}
A.l.prototype={}
A.aA.prototype={}
A.aC.prototype={}
A.bB.prototype={}
A.bW.prototype={}
A.V.prototype={}
A.y.prototype={}
A.x.prototype={}
A.T.prototype={}
A.ao.prototype={}
A.bP.prototype={}
A.bq.prototype={}
A.br.prototype={}
A.bs.prototype={}
A.ah.prototype={}
A.bg.prototype={}
A.bt.prototype={}
A.bp.prototype={}
A.bC.prototype={}
A.bN.prototype={}
A.bY.prototype={}
A.bS.prototype={}
A.cs.prototype={}
A.cb.prototype={
aj(){var s,r,q,p,o,n
for(r=this.a,q=A.eX(r,r.r,r.$ti.c),p=q.$ti.c;q.k();){o=q.d
s=o==null?p.a(o):o
try{s.$0()}catch(n){}}if(r.a>0){r.b=r.c=r.d=r.e=r.f=null
r.a=0
r.ab()}}}
A.dJ.prototype={
$0(){var s,r,q,p,o=this,n=o.a
n.aj()
s=o.b.$0()
r=o.c
q=A.dO(r==null?t.c.a(s):r.$1(s),n)
n=o.d
n.textContent=""
for(r=q.length,p=0;p<q.length;q.length===r||(0,A.be)(q),++p)n.appendChild(q[p])},
$S:0}
A.dI.prototype={
$0(){this.a.$0()},
$S:1}
A.dH.prototype={
$0(){this.a.$0()
this.b.aj()},
$S:0}
A.dF.prototype={
$1(a){this.b.$1(A.iD(this.a,a))},
$S:16}
A.ch.prototype={
v(){var s=this,r="px-2 py-0.5 rounded bg-[#1E1E24] hover:bg-[#27272A] text-xs font-mono text-zinc-300 cursor-pointer",q="flex items-center gap-2",p="text-zinc-400",o=t.N,n=t.t
return A.cV(A.Z(["id","benchmark"],o,o),A.c([A.h(A.c([A.a(u.a,"Real-Time Telemetry"),A.e8(u.d,"Fine-Grained Signals vs VDOM Diffing"),A.bQ("text-zinc-400 text-base leading-relaxed","Unlike React or Flutter which recreate virtual element trees on every state change, Bloom binds signals directly to individual DOM text nodes and attributes with zero reconciliation overhead.")],n),"text-center max-w-3xl mx-auto mb-12"),A.h(A.c([A.h(A.c([A.h(A.c([A.ay(A.c([new A.y(new A.cj(s)),new A.y(new A.ck(s))],n),"px-4 py-2.5 rounded-lg font-medium text-xs flex items-center gap-2 cursor-pointer transition-all bg-indigo-600 hover:bg-indigo-500 text-white shadow-md shadow-indigo-600/20",new A.cl(s),null),A.h(A.c([A.a("text-xs text-zinc-400 font-mono","Nodes:"),new A.y(new A.cm(s)),A.ay(B.a,r,new A.cn(s),"-"),A.ay(B.a,r,new A.co(s),"+")],n),"flex items-center gap-3 bg-[#14141A] px-4 py-2 rounded-lg border border-[#27272A]")],n),"flex items-center gap-4 flex-wrap"),A.h(A.c([A.h(A.c([A.a("w-2 h-2 rounded-full bg-emerald-400",null),A.a(p,"FPS:"),new A.y(new A.cp(s))],n),q),A.h(A.c([A.a("w-2 h-2 rounded-full bg-indigo-400",null),A.a(p,"Patch Latency:"),new A.y(new A.cq(s))],n),q)],n),"flex items-center gap-6 font-mono text-xs")],n),"flex flex-col md:flex-row md:items-center justify-between gap-6 pb-6 border-b border-[#1E1E24]"),A.h(A.c([A.h(A.c([new A.y(new A.cr(s))],n),"grid grid-cols-3 sm:grid-cols-6 md:grid-cols-12 gap-2.5")],n),"pt-6")],n),"rounded-2xl bg-[#101014] border border-[#1E1E24] p-6 sm:p-8 shadow-2xl overflow-hidden")],n),"py-20 px-6 max-w-7xl mx-auto")}}
A.cl.prototype={
$1(a){var s=this.a.a.f
s.sj(!s.gj())
return null},
$S:2}
A.cj.prototype={
$0(){return this.a.a.f.gj()?new A.x('<svg class="w-3.5 h-3.5 animate-spin" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"></path></svg>'):new A.x('<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>')},
$S:7}
A.ck.prototype={
$0(){return A.a(null,this.a.a.f.gj()?"Pause Stress Ticker":"Run Live Stress Ticker")},
$S:3}
A.cm.prototype={
$0(){return A.a("text-xs font-mono font-bold text-white",""+this.a.a.b.gj())},
$S:3}
A.cn.prototype={
$1(a){var s=this.a.a
return s.ao(B.b.ah(s.b.gj()-12,12,120))},
$S:2}
A.co.prototype={
$1(a){var s=this.a.a
return s.ao(B.b.ah(s.b.gj()+12,12,120))},
$S:2}
A.cp.prototype={
$0(){return A.a("text-emerald-400 font-bold",""+this.a.a.c.gj())},
$S:3}
A.cq.prototype={
$0(){return A.a("text-indigo-400 font-bold",A.o(this.a.a.d.gj())+" ms")},
$S:3}
A.cr.prototype={
$0(){var s=J.e4(this.a.a.e.gj(),new A.ci(),t._)
s=A.ec(s,s.$ti.i("E.E"))
return new A.V(s)},
$S:17}
A.ci.prototype={
$1(a){return A.h(A.c([A.a("text-[10px] font-mono text-zinc-500","#"+a),A.a("text-sm font-mono font-bold text-indigo-400 mt-1",""+B.b.a0(a*137,999))],t.t),"p-3 rounded-lg bg-[#14141A] border border-[#27272A] flex flex-col items-center justify-center transition-colors")},
$S:18}
A.ct.prototype={
v(){var s=this,r="flex items-center gap-2",q="w-3 h-3 rounded-full bg-[#27272A]",p=t.N,o=t.t
return A.cV(A.Z(["id","code"],p,p),A.c([A.h(A.c([A.a(u.a,"Developer Ergonomics"),A.e8(u.d,"Clean, Declarative Pure Dart"),A.bQ("text-zinc-400 text-base leading-relaxed","No HTML templates, no JSX, and zero dynamic code generation at runtime. Every component is a strongly-typed AST descriptor tree.")],o),"text-center max-w-3xl mx-auto mb-12"),A.h(A.c([A.h(A.c([A.h(A.c([A.a(q,null),A.a(q,null),A.a(q,null)],o),r),A.h(A.c([s.T("main.dart","UI Component"),s.T("ssr_router.dart","Server SSR"),s.T("bloom.yaml","NPM Config")],o),r),A.a("text-[11px] font-mono text-zinc-500 hidden sm:block","Dart 3.5")],o),"px-4 py-3 bg-[#101014] border-b border-[#1E1E24] flex items-center justify-between"),A.h(A.c([new A.y(new A.cw(s))],o),"p-6 font-mono text-xs sm:text-sm leading-relaxed overflow-x-auto text-zinc-300 custom-scrollbar")],o),"max-w-4xl mx-auto rounded-2xl bg-[#09090B] border border-[#1E1E24] shadow-2xl overflow-hidden")],o),"py-20 px-6 max-w-7xl mx-auto")},
T(a,b){return new A.y(new A.cv(this,a,b))},
aO(a){var s="text-zinc-500",r="text-indigo-400",q="import",p=null,o="text-violet-400",n=" main() {\n",m=t.t
switch(a){case"ssr_router.dart":return A.ed(A.c([A.a(s,"// apps/server/bin/server.dart\n"),A.a(r,q),A.a(p," 'package:bloom_framework/bloom.dart';\n"),A.a(r,q),A.a(p," 'package:bloom_js_native/bloom_js_native.dart';\n\n"),A.a(o,"void"),A.a(p,n),A.a(p,"  final router = BloomApiRouter();\n\n"),A.a(s,"  // High-throughput SSR endpoint (<1ms response)\n"),A.a(p,"  router.ssr('/', (req) => Div(\n"),A.a(p,"    className: 'min-h-screen bg-black text-white',\n"),A.a(p,"    children: [\n"),A.a(p,"      H1(text: 'Welcome to Bloom'),\n"),A.a(p,"      P(text: 'Zero JS baseline loaded statically.'),\n"),A.a(p,"    ],\n"),A.a(p,"  ));\n\n"),A.a(p,"  router.listen(port: 8080);\n"),A.a(p,"}\n")],m))
case"bloom.yaml":return A.ed(A.c([A.a(s,"# bloom.yaml\n"),A.a(r,"name"),A.a(p,": showcase_app\n"),A.a(r,"target"),A.a(p,": web_dom\n\n"),A.a(o,"npm_packages"),A.a(p,":\n"),A.a(p,"  three:\n"),A.a(p,"    npm_name: three\n"),A.a(p,"    version: 0.160.0\n"),A.a(p,"    vendor_file: web/vendor/three.min.js\n"),A.a(p,"  canvas-confetti:\n"),A.a(p,"    npm_name: canvas-confetti\n"),A.a(p,"    version: 1.9.3\n"),A.a(p,"    vendor_file: web/vendor/canvas-confetti.min.js\n")],m))
default:return A.ed(A.c([A.a(s,"// lib/main.dart\n"),A.a(r,q),A.a(p," 'package:bloom_js_native/bloom_js_native.dart';\n"),A.a(r,q),A.a(p," 'package:bloom_js_native/browser.dart';\n\n"),A.a(o,"void"),A.a(p,n),A.a(p,"  final count = signal(0);\n"),A.a(p,"  final isEven = computed(() => count.value.isEven);\n\n"),A.a(p,"  mount(\n"),A.a(p,"    Div(\n"),A.a(p,"      className: 'p-6 bg-zinc-900 rounded-xl border border-zinc-800',\n"),A.a(p,"      children: [\n"),A.a(p,"        Live(() => H2(text: 'Count: ${count.value}')),\n"),A.a(p,"        Button(\n"),A.a(p,"          className: 'px-4 py-2 bg-indigo-600 rounded text-white',\n"),A.a(p,"          onClick: (_) => count.value++,\n"),A.a(p,"          text: 'Increment',\n"),A.a(p,"        ),\n"),A.a(p,"      ],\n"),A.a(p,"    ),\n"),A.a(p,"    '#app',\n"),A.a(p,"  );\n"),A.a(p,"}\n")],m))}}}
A.cw.prototype={
$0(){var s=this.a
return s.aO(s.a.a.gj())},
$S:8}
A.cv.prototype={
$0(){var s=this.a,r=this.b
return A.ay(B.a,"px-3 py-1 text-xs font-mono rounded-md transition-all cursor-pointer "+(s.a.a.gj()===r?"bg-[#1E1E24] text-white font-medium shadow-sm border border-[#27272A]":"text-zinc-500 hover:text-zinc-300"),new A.cu(s,r),this.c)},
$S:19}
A.cu.prototype={
$1(a){this.a.a.a.sj(this.b)
return null},
$S:2}
A.cz.prototype={
H(a,b,c,d){var s=null,r=t.t
return A.h(A.c([A.h(A.c([A.h(A.c([A.h(A.c([new A.x('<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">'+b+"</svg>")],r),"w-12 h-12 rounded-xl bg-[#14141A] border border-[#27272A] flex items-center justify-center text-indigo-400 group-hover:text-white group-hover:bg-indigo-600 transition-colors"),A.a("text-xs font-mono px-2.5 py-1 rounded-full bg-[#14141A] text-zinc-400 border border-[#27272A]",c)],r),"flex items-center justify-between mb-6"),new A.bs("h3",d,"text-xl font-bold text-white mb-3 tracking-tight",s,s,A.a5(s,s,s,s,s),B.a),A.bQ("text-zinc-400 text-sm leading-relaxed",a)],r),s)],r),"group p-8 rounded-2xl bg-[#101014] border border-[#1E1E24] hover:border-indigo-500/40 transition-all duration-300 relative overflow-hidden flex flex-col justify-between shadow-lg")}}
A.cE.prototype={
v(){var s=this,r=null,q=t.t,p=A.h(A.c([new A.x('<canvas id="three-hero-canvas" class="w-full h-full max-w-5xl max-h-[600px]"></canvas>')],q),"absolute inset-0 pointer-events-none flex items-center justify-center opacity-60"),o=A.h(A.c([A.a("w-2 h-2 rounded-full bg-indigo-500 animate-pulse",r),A.a(r,"Bloom JS Native \u2014 Fine-Grained Web Architecture for Dart")],q),"inline-flex items-center gap-2 px-3.5 py-1.5 rounded-full bg-[#14141A] border border-[#27272A] text-xs font-medium text-zinc-300 mb-8 shadow-sm"),n=A.c([A.a(r,"Pure Dart on the DOM.\n"),A.a("bg-gradient-to-r from-indigo-400 via-violet-400 to-indigo-200 bg-clip-text text-transparent","0kB Flutter Runtime.")],q)
return A.cV(r,A.c([p,A.h(A.c([o,new A.bq("h1",r,"text-5xl sm:text-6xl md:text-7xl font-extrabold tracking-tight text-white mb-6 leading-[1.1]",r,r,A.a5(r,r,r,r,r),n),A.bQ("max-w-2xl text-lg sm:text-xl text-zinc-400 mb-10 leading-relaxed font-normal","Dart owns reactivity, compilation, and tooling. The browser owns rendering. Surgical ESM imports via Bun with sub-millisecond SSR execution."),A.h(A.c([A.ay(A.c([A.a("text-xs font-mono text-zinc-500 select-none","$"),A.a("text-sm font-mono text-zinc-200","bloom create my_app --target=web_dom"),new A.y(new A.cF(s))],q),"group px-5 py-3.5 rounded-xl bg-[#14141A] hover:bg-[#1E1E24] border border-[#27272A] hover:border-indigo-500/50 flex items-center gap-3 transition-all cursor-pointer shadow-lg shadow-black/40",new A.cG(s),r),A.ae(A.c([new A.x('<svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24"><path fill-rule="evenodd" clip-rule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.53 1.032 1.53 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"/></svg>'),A.a(r,"Star on GitHub")],q),"px-6 py-3.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-semibold flex items-center gap-2 transition-all shadow-lg shadow-indigo-600/25 cursor-pointer","https://github.com/Chidi09/Bloom",r)],q),"flex flex-col sm:flex-row items-center gap-4 mb-16 w-full justify-center"),A.h(A.c([s.J("< 1ms","SSR HTML Baseline","text-indigo-400"),s.J("82 kB","Production Bundle","text-violet-400"),s.J("0 kB","Flutter Engine","text-cyan-400"),s.J("100%","Fine-Grained Signals","text-emerald-400")],q),"grid grid-cols-2 sm:grid-cols-4 gap-4 w-full pt-8 border-t border-[#1E1E24]")],q),"relative max-w-5xl mx-auto text-center flex flex-col items-center z-10")],q),"relative pt-24 pb-20 px-6 overflow-hidden")},
J(a,b,c){return A.h(A.c([A.a("text-2xl sm:text-3xl font-extrabold font-mono mb-1 "+c,a),A.a("text-xs text-zinc-400 font-medium",b)],t.t),"p-4 rounded-xl bg-[#101014] border border-[#1E1E24] text-center flex flex-col items-center justify-center")}}
A.cG.prototype={
$1(a){return this.a.a.an()},
$S:2}
A.cF.prototype={
$0(){return this.a.a.w.gj()?new A.x('<svg class="w-4 h-4 text-emerald-400 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7"/></svg>'):new A.x('<svg class="w-4 h-4 text-zinc-400 group-hover:text-white ml-2 transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>')},
$S:7}
A.cO.prototype={
v(){var s=null,r="hover:text-white transition-colors",q=t.t
return new A.bt("header",s,"sticky top-0 z-50 w-full border-b border-[#1E1E24] bg-[#09090B]/80 backdrop-blur-md",s,s,s,A.c([A.h(A.c([A.h(A.c([A.h(A.c([new A.x('<svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M13 10V3L4 14h7v7l9-11h-7z"/></svg>')],q),"w-8 h-8 rounded-lg bg-gradient-to-br from-indigo-500 to-violet-600 flex items-center justify-center font-bold text-white shadow-lg shadow-indigo-500/20 text-sm tracking-tight"),A.h(A.c([A.a("font-bold text-lg text-white tracking-tight","Bloom"),A.a("text-xs font-mono px-2 py-0.5 rounded-full bg-[#1E1E24] text-indigo-400 border border-[#27272A]","JS Native")],q),"flex items-baseline gap-2")],q),"flex items-center gap-3"),new A.bN("nav",s,"hidden md:flex items-center gap-8 text-sm text-zinc-400 font-medium",s,s,s,A.c([A.ae(B.a,r,"#features","Architecture"),A.ae(B.a,r,"#benchmark","Telemetry Benchmark"),A.ae(B.a,r,"#code","Code Showcase"),A.ae(B.a,r,"https://github.com/Chidi09/Bloom","Documentation")],q)),A.h(A.c([A.ay(A.c([new A.x('<svg class="w-3.5 h-3.5 text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>'),A.a(s,"bloom create")],q),"px-4 py-2 text-xs font-mono rounded-lg bg-[#14141A] hover:bg-[#1E1E24] text-zinc-300 border border-[#27272A] flex items-center gap-2 transition-all cursor-pointer shadow-sm",new A.cP(this),s)],q),"flex items-center gap-4")],q),"max-w-7xl mx-auto px-6 h-16 flex items-center justify-between")],q))}}
A.cP.prototype={
$1(a){return this.a.a.an()},
$S:2}
A.e0.prototype={
$0(){var s=this.a.r.gj()
if(s==null)return B.x
return A.h(A.c([new A.x('<svg class="w-4 h-4 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>'),A.a("text-xs font-mono text-zinc-200",s)],t.t),"fixed bottom-6 right-6 z-50 px-4 py-3 rounded-xl bg-[#14141A] border border-[#27272A] shadow-2xl flex items-center gap-3 animate-bounce")},
$S:8}
A.d2.prototype={
b0(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1=this
try{d=a1.a
s=d.clientWidth>0?d.clientWidth:800
r=d.clientHeight>0?d.clientHeight:500
c=v.G
q=c.THREE.Scene()
p=c.THREE.PerspectiveCamera(45,s/r,0.1,1000)
p.gbm().sbp(5)
b=t.N
a=t.z
o=A.cd(A.dZ(A.Z(["canvas",d,"alpha",!0,"antialias",!0],b,a)))
n=c.THREE.WebGLRenderer(o)
n.au(s,r)
n.bk(c.window.devicePixelRatio)
m=c.THREE.IcosahedronGeometry(1.6,2)
l=A.cd(A.dZ(A.Z(["color",6514417,"wireframe",!0,"transparent",!0,"opacity",0.35],b,a)))
k=c.THREE.MeshBasicMaterial(l)
j=c.THREE.Mesh(m,k)
J.eA(q,j)
i=c.THREE.IcosahedronGeometry(0.9,1)
h=A.cd(A.dZ(A.Z(["color",9133302,"wireframe",!0,"transparent",!0,"opacity",0.2],b,a)))
g=c.THREE.MeshBasicMaterial(h)
f=c.THREE.Mesh(i,g)
J.eA(q,f)
a1.b=!0
e=new A.d3(a1,j,f,n,q,p)
c.window.requestAnimationFrame(A.dL(e))
c.window.onresize=A.dL(new A.d4(a1,p,n))}catch(a0){}}}
A.d3.prototype={
$1(a){var s,r=this
if(!r.a.b)return
s=r.b.gX()
s.sZ(s.gZ().ap(0,0.003))
s=r.b.gX()
s.sa_(s.ga_().ap(0,0.005))
s=r.c.gX()
s.sZ(s.gZ().aw(0,0.004))
s=r.c.gX()
s.sa_(s.ga_().aw(0,0.006))
r.d.bn(r.e,r.f)
v.G.window.requestAnimationFrame(A.dL(r))},
$S:20}
A.d4.prototype={
$1(a){var s,r,q=this.a
if(!q.b)return
q=q.a
s=q.clientWidth
r=q.clientHeight
if(s>0&&r>0){q=this.b
q.sbl(s/r)
q.bo()
this.c.au(s,r)}},
$S:21}
A.cW.prototype={
ao(a){var s,r,q
this.b.sj(a)
s=J.eJ(a,t.S)
for(r=0;r<a;r=q){q=r+1
s[r]=q}this.e.sj(s)},
an(){this.w.sj(!0)
this.av("Copied: bloom create my_app --target=web_dom")
A.fV(0.5,0.3)
A.eI(B.i,new A.d_(this),t.P)},
av(a){this.r.sj(a)
A.eI(B.i,new A.cZ(this,a),t.P)},
aT(){A.hh(B.w,new A.cY(this))}}
A.d_.prototype={
$0(){this.a.w.sj(!1)},
$S:1}
A.cZ.prototype={
$0(){var s=this.a.r
if(s.gj()===this.b)s.sj(null)},
$S:1}
A.cY.prototype={
$1(a){var s,r,q,p,o=this.a
if(o.f.gj()){s=o.e
r=s.gj()
q=new A.d1()
$.ex()
p=$.cT.$0()
q.a=p
q.b=null
p=J.e4(r,new A.cX(),t.S)
p=A.ec(p,p.$ti.i("E.E"))
s.sj(p)
s=$.cT.$0()
q.b=s
o.d.sj(A.iK(B.k.bg(q.gaY()/1000,2)))}},
$S:22}
A.cX.prototype={
$1(a){return B.b.a0(a,99)+1},
$S:23}
A.bn.prototype={
aC(a,b){var s
try{this.a5()}catch(s){this.ai()
throw s}},
a5(){var s,r,q=this,p=q.aS()
try{if((q.r&8)!==0)return
r=q.a
if(r==null)return
s=r.$0()
if(t.Z.b(s))q.d=s}finally{p.$0()}},
aS(){var s,r=this,q=r.r
if((q&1)!==0)throw A.e(new A.az())
q|=1
r.r=q
r.r=q&4294967287
A.f9(r)
A.iq(r)
$.L=$.L+1
s=$.a3
$.a3=r
return new A.cx(r,s)},
ai(){var s,r,q,p=this
if(p.x)return
if(((p.r|=8)&1)===0)A.ek(p)
for(s=p.w,s=A.eX(s,s.r,s.$ti.c),r=s.$ti.c;s.k();){q=s.d;(q==null?r.a(q):q).$0()}p.x=!0}}
A.cx.prototype={
$0(){var s=this.a
if($.a3!==s)A.e2(A.eH("Out-of-order effect"))
A.hW(s)
$.a3=this.b
if(((s.r&=4294967294)&8)!==0)A.ek(s)
A.el()
return null},
$S:0}
A.aR.prototype={
aN(){var s,r,q
for(s=this.r;s!=null;s=s.f){r=s.d
q=r.r
if((q&2)===0){r.r=q|2
r.f=$.dG
$.dG=r}}},
h(a){return A.o(this.gj())},
$0(){return this.gj()},
aU(a){var s,r,q=this.r
if(q!=null){s=a.e
r=a.f
if(s!=null){s.f=r
a.e=null}if(r!=null){r.e=s
a.f=null}if(a===q)this.r=r}}}
A.aT.prototype={
ar(a){var s=this,r=s.Q
r===$&&A.cf()
r=s.as.$2(a,r)
if(r)return!1
if($.dK>100)throw A.e(new A.az())
r=s.Q
r===$&&A.cf()
if(a==null?r!=null:a!==r){if(r==null)s.z===$&&A.cf()
s.Q=a}++s.e
$.fc=$.fc+1
$.L=$.L+1
try{s.aN()}finally{A.el()}return!0},
sj(a){if(this.b)throw A.e(new A.c_("A "+A.fq(this).h(0)+" signal was written after being disposed.\nOnce you have called dispose() on a signal, it can no longer be used."))
this.ar(a)},
gj(){var s,r,q=this
if(q.b){A.iX("signal warning: ["+q.d+"|"+A.o(q.c)+"] has been read after disposed: "+A.eP().h(0))
s=q.Q
s===$&&A.cf()
return s}r=A.hH(q)
if(r!=null)r.r=q.e
s=q.Q
s===$&&A.cf()
return s}}
A.d0.prototype={
$2(a,b){return a==null?b==null:a===b},
$S(){return this.a.i("eo(0,0)")}}
A.dt.prototype={}
A.bZ.prototype={
h(a){return this.a}}
A.c_.prototype={}
A.az.prototype={};(function aliases(){var s=J.P.prototype
s.aA=s.h
s=A.aR.prototype
s.a1=s.aU})();(function installTearOffs(){var s=hunkHelpers._static_0,r=hunkHelpers._static_1,q=hunkHelpers._instance_0u
s(A,"il","h6",5)
r(A,"iF","hj",4)
r(A,"iG","hk",4)
r(A,"iH","hl",4)
s(A,"fm","ix",0)
q(A.bn.prototype,"gaX","ai",0)})();(function inheritance(){var s=hunkHelpers.mixin,r=hunkHelpers.inherit,q=hunkHelpers.inheritMany
r(A.i,null)
q(A.i,[A.ea,J.bu,A.aS,J.bh,A.m,A.d,A.ak,A.bD,A.aB,A.M,A.d6,A.cQ,A.bo,A.b6,A.a_,A.cL,A.bA,A.bz,A.C,A.c8,A.dz,A.b7,A.H,A.c9,A.D,A.c6,A.dD,A.ca,A.an,A.ds,A.ar,A.q,A.ai,A.bO,A.aU,A.dg,A.cC,A.a0,A.w,A.cc,A.d1,A.c2,A.af,A.l,A.cs,A.cb,A.ch,A.ct,A.cz,A.cE,A.cO,A.d2,A.cW,A.bn,A.aR,A.dt])
q(J.bu,[J.bw,J.aF,J.aI,J.aH,J.aJ,J.aG,J.aj])
q(J.aI,[J.P,J.t,A.al,A.aO])
q(J.P,[J.bR,J.aV,J.O])
r(J.bv,A.aS)
r(J.cK,J.t)
q(J.aG,[J.aE,J.bx])
q(A.m,[A.aK,A.J,A.by,A.c5,A.bX,A.c7,A.bi,A.G,A.aW,A.c4,A.c0,A.bm,A.bZ,A.az])
q(A.d,[A.f,A.a1])
q(A.f,[A.E,A.aL,A.Y,A.aZ])
r(A.U,A.a1)
r(A.I,A.E)
q(A.M,[A.bk,A.bl,A.c3,A.dV,A.dX,A.dd,A.dc,A.dp,A.dw,A.e_,A.dF,A.cl,A.cn,A.co,A.ci,A.cu,A.cG,A.cP,A.d3,A.d4,A.cY,A.cX])
q(A.bk,[A.cR,A.de,A.df,A.dy,A.dx,A.cD,A.dh,A.dk,A.dj,A.di,A.dn,A.dm,A.dl,A.dv,A.dQ,A.dJ,A.dI,A.dH,A.cj,A.ck,A.cm,A.cp,A.cq,A.cr,A.cw,A.cv,A.cF,A.e0,A.d_,A.cZ,A.cx])
r(A.aQ,A.J)
q(A.c3,[A.c1,A.ag])
q(A.a_,[A.X,A.aY])
q(A.bl,[A.dW,A.dq,A.cN,A.d0])
q(A.aO,[A.bE,A.am])
q(A.am,[A.b1,A.b3])
r(A.b2,A.b1)
r(A.aM,A.b2)
r(A.b4,A.b3)
r(A.aN,A.b4)
q(A.aM,[A.bF,A.bG])
q(A.aN,[A.bH,A.bI,A.bJ,A.bK,A.bL,A.aP,A.bM])
r(A.b8,A.c7)
r(A.du,A.dD)
r(A.b_,A.aY)
r(A.b5,A.an)
r(A.b0,A.b5)
r(A.bV,A.G)
q(A.l,[A.aA,A.aC,A.bB,A.bW])
r(A.V,A.aC)
r(A.y,A.bB)
r(A.x,A.bW)
q(A.aA,[A.T,A.ao,A.bP,A.bq,A.br,A.bs,A.ah,A.bg,A.bt,A.bp,A.bC,A.bN,A.bY,A.bS])
r(A.aT,A.aR)
r(A.c_,A.bZ)
s(A.b1,A.q)
s(A.b2,A.aB)
s(A.b3,A.q)
s(A.b4,A.aB)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{b:"int",k:"double",fs:"num",Q:"String",eo:"bool",w:"Null",n:"List",i:"Object",j2:"Map",p:"JSObject"},mangledNames:{},types:["~()","w()","~(af)","ao()","~(~())","b()","w(@)","x()","l()","@(@)","@(@,Q)","@(Q)","w(~())","w(i,ap)","~(i?,i?)","i?(i?)","~(p)","V()","T(b)","ah()","~(k)","w(p)","~(d5)","b(b)"],interceptorsByTag:null,leafTags:null,arrayRti:Symbol("$ti")}
A.hD(v.typeUniverse,JSON.parse('{"bR":"P","aV":"P","O":"P","j3":"al","bw":{"j":[]},"aF":{"w":[],"j":[]},"aI":{"p":[]},"P":{"p":[]},"t":{"n":["1"],"f":["1"],"p":[],"d":["1"]},"bv":{"aS":[]},"cK":{"t":["1"],"n":["1"],"f":["1"],"p":[],"d":["1"]},"aG":{"k":[]},"aE":{"k":[],"b":[],"j":[]},"bx":{"k":[],"j":[]},"aj":{"Q":[],"j":[]},"aK":{"m":[]},"f":{"d":["1"]},"E":{"f":["1"],"d":["1"]},"a1":{"d":["2"],"d.E":"2"},"U":{"a1":["1","2"],"f":["2"],"d":["2"],"d.E":"2"},"I":{"E":["2"],"f":["2"],"d":["2"],"d.E":"2","E.E":"2"},"aQ":{"J":[],"m":[]},"by":{"m":[]},"c5":{"m":[]},"b6":{"ap":[]},"M":{"W":[]},"bk":{"W":[]},"bl":{"W":[]},"c3":{"W":[]},"c1":{"W":[]},"ag":{"W":[]},"bX":{"m":[]},"X":{"a_":["1","2"]},"aL":{"f":["1"],"d":["1"],"d.E":"1"},"Y":{"f":["a0<1,2>"],"d":["a0<1,2>"],"d.E":"a0<1,2>"},"al":{"p":[],"e6":[],"j":[]},"aO":{"p":[]},"bE":{"e7":[],"p":[],"j":[]},"am":{"z":["1"],"p":[]},"aM":{"q":["k"],"n":["k"],"z":["k"],"f":["k"],"p":[],"d":["k"]},"aN":{"q":["b"],"n":["b"],"z":["b"],"f":["b"],"p":[],"d":["b"]},"bF":{"cA":[],"q":["k"],"n":["k"],"z":["k"],"f":["k"],"p":[],"d":["k"],"j":[],"q.E":"k"},"bG":{"cB":[],"q":["k"],"n":["k"],"z":["k"],"f":["k"],"p":[],"d":["k"],"j":[],"q.E":"k"},"bH":{"cH":[],"q":["b"],"n":["b"],"z":["b"],"f":["b"],"p":[],"d":["b"],"j":[],"q.E":"b"},"bI":{"cI":[],"q":["b"],"n":["b"],"z":["b"],"f":["b"],"p":[],"d":["b"],"j":[],"q.E":"b"},"bJ":{"cJ":[],"q":["b"],"n":["b"],"z":["b"],"f":["b"],"p":[],"d":["b"],"j":[],"q.E":"b"},"bK":{"d8":[],"q":["b"],"n":["b"],"z":["b"],"f":["b"],"p":[],"d":["b"],"j":[],"q.E":"b"},"bL":{"d9":[],"q":["b"],"n":["b"],"z":["b"],"f":["b"],"p":[],"d":["b"],"j":[],"q.E":"b"},"aP":{"da":[],"q":["b"],"n":["b"],"z":["b"],"f":["b"],"p":[],"d":["b"],"j":[],"q.E":"b"},"bM":{"db":[],"q":["b"],"n":["b"],"z":["b"],"f":["b"],"p":[],"d":["b"],"j":[],"q.E":"b"},"c7":{"m":[]},"b8":{"J":[],"m":[]},"b7":{"d5":[]},"H":{"m":[]},"D":{"aD":["1"]},"aY":{"a_":["1","2"]},"b_":{"aY":["1","2"],"a_":["1","2"]},"aZ":{"f":["1"],"d":["1"],"d.E":"1"},"b0":{"an":["1"],"f":["1"],"d":["1"]},"an":{"f":["1"],"d":["1"]},"b5":{"an":["1"],"f":["1"],"d":["1"]},"n":{"f":["1"],"d":["1"]},"bi":{"m":[]},"J":{"m":[]},"G":{"m":[]},"bV":{"m":[]},"aW":{"m":[]},"c4":{"m":[]},"c0":{"m":[]},"bm":{"m":[]},"bO":{"m":[]},"aU":{"m":[]},"cc":{"ap":[]},"V":{"l":[]},"x":{"l":[]},"T":{"l":[]},"ao":{"l":[]},"ah":{"l":[]},"aA":{"l":[]},"aC":{"l":[]},"bB":{"l":[]},"bW":{"l":[]},"y":{"l":[]},"bP":{"l":[]},"bq":{"l":[]},"br":{"l":[]},"bs":{"l":[]},"bg":{"l":[]},"bt":{"l":[]},"bp":{"l":[]},"bC":{"l":[]},"bN":{"l":[]},"bY":{"l":[]},"bS":{"l":[]},"aT":{"aR":["1"]},"bZ":{"m":[]},"c_":{"m":[]},"az":{"m":[]},"cJ":{"n":["b"],"f":["b"],"d":["b"]},"db":{"n":["b"],"f":["b"],"d":["b"]},"da":{"n":["b"],"f":["b"],"d":["b"]},"cH":{"n":["b"],"f":["b"],"d":["b"]},"d8":{"n":["b"],"f":["b"],"d":["b"]},"cI":{"n":["b"],"f":["b"],"d":["b"]},"d9":{"n":["b"],"f":["b"],"d":["b"]},"cA":{"n":["k"],"f":["k"],"d":["k"]},"cB":{"n":["k"],"f":["k"],"d":["k"]}}'))
A.hC(v.typeUniverse,JSON.parse('{"f":1,"aB":1,"bA":1,"am":1,"b5":1}'))
var u={c:"Error handler must accept one Object or one Object and a StackTrace as arguments, and return a value of the returned future's type",d:"text-3xl sm:text-4xl font-bold text-white mt-2 mb-4",a:"text-xs font-mono text-indigo-400 font-semibold uppercase tracking-wider"}
var t=(function rtii(){var s=A.eq
return{c:s("l"),J:s("e6"),Y:s("e7"),_:s("T"),V:s("f<@>"),Q:s("m"),B:s("cA"),q:s("cB"),Z:s("W"),W:s("cH"),k:s("cI"),U:s("cJ"),a:s("d<@>"),t:s("t<l>"),O:s("t<p>"),s:s("t<Q>"),b:s("t<@>"),T:s("aF"),m:s("p"),g:s("O"),p:s("z<@>"),j:s("n<@>"),L:s("n<b>"),P:s("w"),K:s("i"),d:s("j4"),l:s("ap"),N:s("Q"),D:s("d5"),R:s("j"),e:s("J"),E:s("d8"),w:s("d9"),f:s("da"),F:s("db"),o:s("aV"),A:s("b_<i?,i?>"),y:s("eo"),i:s("k"),z:s("@"),v:s("@(i)"),C:s("@(i,ap)"),S:s("b"),h:s("aD<w>?"),G:s("p?"),X:s("i?"),u:s("Q?"),r:s("eo?"),I:s("k?"),x:s("b?"),n:s("fs?"),H:s("fs"),b9:s("~"),M:s("~()"),co:s("~(af)")}})();(function constants(){var s=hunkHelpers.makeConstList
B.y=J.bu.prototype
B.j=J.t.prototype
B.b=J.aE.prototype
B.k=J.aG.prototype
B.d=J.aj.prototype
B.z=J.O.prototype
B.A=J.aI.prototype
B.l=J.bR.prototype
B.e=J.aV.prototype
B.f=function getTagFallback(o) {
  var s = Object.prototype.toString.call(o);
  return s.substring(8, s.length - 1);
}
B.m=function() {
  var toStringFunction = Object.prototype.toString;
  function getTag(o) {
    var s = toStringFunction.call(o);
    return s.substring(8, s.length - 1);
  }
  function getUnknownTag(object, tag) {
    if (/^HTML[A-Z].*Element$/.test(tag)) {
      var name = toStringFunction.call(object);
      if (name == "[object Object]") return null;
      return "HTMLElement";
    }
  }
  function getUnknownTagGenericBrowser(object, tag) {
    if (object instanceof HTMLElement) return "HTMLElement";
    return getUnknownTag(object, tag);
  }
  function prototypeForTag(tag) {
    if (typeof window == "undefined") return null;
    if (typeof window[tag] == "undefined") return null;
    var constructor = window[tag];
    if (typeof constructor != "function") return null;
    return constructor.prototype;
  }
  function discriminator(tag) { return null; }
  var isBrowser = typeof HTMLElement == "function";
  return {
    getTag: getTag,
    getUnknownTag: isBrowser ? getUnknownTagGenericBrowser : getUnknownTag,
    prototypeForTag: prototypeForTag,
    discriminator: discriminator };
}
B.r=function(getTagFallback) {
  return function(hooks) {
    if (typeof navigator != "object") return hooks;
    var userAgent = navigator.userAgent;
    if (typeof userAgent != "string") return hooks;
    if (userAgent.indexOf("DumpRenderTree") >= 0) return hooks;
    if (userAgent.indexOf("Chrome") >= 0) {
      function confirm(p) {
        return typeof window == "object" && window[p] && window[p].name == p;
      }
      if (confirm("Window") && confirm("HTMLElement")) return hooks;
    }
    hooks.getTag = getTagFallback;
  };
}
B.n=function(hooks) {
  if (typeof dartExperimentalFixupGetTag != "function") return hooks;
  hooks.getTag = dartExperimentalFixupGetTag(hooks.getTag);
}
B.q=function(hooks) {
  if (typeof navigator != "object") return hooks;
  var userAgent = navigator.userAgent;
  if (typeof userAgent != "string") return hooks;
  if (userAgent.indexOf("Firefox") == -1) return hooks;
  var getTag = hooks.getTag;
  var quickMap = {
    "BeforeUnloadEvent": "Event",
    "DataTransfer": "Clipboard",
    "GeoGeolocation": "Geolocation",
    "Location": "!Location",
    "WorkerMessageEvent": "MessageEvent",
    "XMLDocument": "!Document"};
  function getTagFirefox(o) {
    var tag = getTag(o);
    return quickMap[tag] || tag;
  }
  hooks.getTag = getTagFirefox;
}
B.p=function(hooks) {
  if (typeof navigator != "object") return hooks;
  var userAgent = navigator.userAgent;
  if (typeof userAgent != "string") return hooks;
  if (userAgent.indexOf("Trident/") == -1) return hooks;
  var getTag = hooks.getTag;
  var quickMap = {
    "BeforeUnloadEvent": "Event",
    "DataTransfer": "Clipboard",
    "HTMLDDElement": "HTMLElement",
    "HTMLDTElement": "HTMLElement",
    "HTMLPhraseElement": "HTMLElement",
    "Position": "Geoposition"
  };
  function getTagIE(o) {
    var tag = getTag(o);
    var newTag = quickMap[tag];
    if (newTag) return newTag;
    if (tag == "Object") {
      if (window.DataView && (o instanceof window.DataView)) return "DataView";
    }
    return tag;
  }
  function prototypeForTagIE(tag) {
    var constructor = window[tag];
    if (constructor == null) return null;
    return constructor.prototype;
  }
  hooks.getTag = getTagIE;
  hooks.prototypeForTag = prototypeForTagIE;
}
B.o=function(hooks) {
  var getTag = hooks.getTag;
  var prototypeForTag = hooks.prototypeForTag;
  function getTagFixed(o) {
    var tag = getTag(o);
    if (tag == "Document") {
      if (!!o.xmlVersion) return "!Document";
      return "!HTMLDocument";
    }
    return tag;
  }
  function prototypeForTagFixed(tag) {
    if (tag == "Document") return null;
    return prototypeForTag(tag);
  }
  hooks.getTag = getTagFixed;
  hooks.prototypeForTag = prototypeForTagFixed;
}
B.h=function(hooks) { return hooks; }

B.t=new A.bO()
B.c=new A.du()
B.u=new A.cc()
B.v=new A.ai(0)
B.i=new A.ai(3e6)
B.w=new A.ai(6e4)
B.a=s([],t.t)
B.x=new A.V(B.a)
B.B=A.F("e6")
B.C=A.F("e7")
B.D=A.F("cA")
B.E=A.F("cB")
B.F=A.F("cH")
B.G=A.F("cI")
B.H=A.F("cJ")
B.I=A.F("d8")
B.J=A.F("d9")
B.K=A.F("da")
B.L=A.F("db")})();(function staticFields(){$.dr=null
$.a7=A.c([],A.eq("t<i>"))
$.eN=null
$.cS=0
$.cT=A.il()
$.eE=null
$.eD=null
$.fr=null
$.fl=null
$.fu=null
$.dS=null
$.dY=null
$.es=null
$.as=null
$.bc=null
$.bd=null
$.en=!1
$.r=B.c
$.fc=0
$.a3=null
$.dG=null
$.L=0
$.dK=0
$.dN=0})();(function lazyInitializers(){var s=hunkHelpers.lazyFinal
s($,"j1","fy",()=>A.dU("_$dart_dartClosure"))
s($,"j0","ew",()=>A.dU("_$dart_dartClosure_dartJSInterop"))
s($,"ji","fK",()=>A.c([new J.bv()],A.eq("t<aS>")))
s($,"j7","fA",()=>A.K(A.d7({
toString:function(){return"$receiver$"}})))
s($,"j8","fB",()=>A.K(A.d7({$method$:null,
toString:function(){return"$receiver$"}})))
s($,"j9","fC",()=>A.K(A.d7(null)))
s($,"ja","fD",()=>A.K(function(){var $argumentsExpr$="$arguments$"
try{null.$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"jd","fG",()=>A.K(A.d7(void 0)))
s($,"je","fH",()=>A.K(function(){var $argumentsExpr$="$arguments$"
try{(void 0).$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"jc","fF",()=>A.K(A.eS(null)))
s($,"jb","fE",()=>A.K(function(){try{null.$method$}catch(r){return r.message}}()))
s($,"jg","fJ",()=>A.K(A.eS(void 0)))
s($,"jf","fI",()=>A.K(function(){try{(void 0).$method$}catch(r){return r.message}}()))
s($,"jh","ey",()=>A.hi())
s($,"j6","ex",()=>{A.h8()
return $.cS})
s($,"j5","fz",()=>A.hd())})();(function nativeSupport(){!function(){var s=function(a){var m={}
m[a]=1
return Object.keys(hunkHelpers.convertToFastObject(m))[0]}
v.getIsolateTag=function(a){return s("___dart_"+a+v.isolateTag)}
var r="___dart_isolate_tags_"
var q=Object[r]||(Object[r]=Object.create(null))
var p="_ZxYxX"
for(var o=0;;o++){var n=s(p+"_"+o+"_")
if(!(n in q)){q[n]=1
v.isolateTag=n
break}}v.dispatchPropertyName=v.getIsolateTag("dispatch_record")}()
hunkHelpers.setOrUpdateInterceptorsByTag({ArrayBuffer:A.al,SharedArrayBuffer:A.al,ArrayBufferView:A.aO,DataView:A.bE,Float32Array:A.bF,Float64Array:A.bG,Int16Array:A.bH,Int32Array:A.bI,Int8Array:A.bJ,Uint16Array:A.bK,Uint32Array:A.bL,Uint8ClampedArray:A.aP,CanvasPixelArray:A.aP,Uint8Array:A.bM})
hunkHelpers.setOrUpdateLeafTags({ArrayBuffer:true,SharedArrayBuffer:true,ArrayBufferView:false,DataView:true,Float32Array:true,Float64Array:true,Int16Array:true,Int32Array:true,Int8Array:true,Uint16Array:true,Uint32Array:true,Uint8ClampedArray:true,CanvasPixelArray:true,Uint8Array:false})
A.am.$nativeSuperclassTag="ArrayBufferView"
A.b1.$nativeSuperclassTag="ArrayBufferView"
A.b2.$nativeSuperclassTag="ArrayBufferView"
A.aM.$nativeSuperclassTag="ArrayBufferView"
A.b3.$nativeSuperclassTag="ArrayBufferView"
A.b4.$nativeSuperclassTag="ArrayBufferView"
A.aN.$nativeSuperclassTag="ArrayBufferView"})()
Function.prototype.$0=function(){return this()}
Function.prototype.$1=function(a){return this(a)}
Function.prototype.$2=function(a,b){return this(a,b)}
Function.prototype.$1$1=function(a){return this(a)}
Function.prototype.$3=function(a,b,c){return this(a,b,c)}
Function.prototype.$4=function(a,b,c,d){return this(a,b,c,d)}
convertAllToFastObject(w)
convertToFastObject($);(function(a){if(typeof document==="undefined"){a(null)
return}if(typeof document.currentScript!="undefined"){a(document.currentScript)
return}var s=document.scripts
function onLoad(b){for(var q=0;q<s.length;++q){s[q].removeEventListener("load",onLoad,false)}a(b.target)}for(var r=0;r<s.length;++r){s[r].addEventListener("load",onLoad,false)}})(function(a){v.currentScript=a
var s=A.iU
if(typeof dartMainRunner==="function"){dartMainRunner(s,[])}else{s([])}})})()
//# sourceMappingURL=main.js.map
