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
if(a[b]!==s){A.k3(b)}a[b]=r}var q=a[b]
a[c]=function(){return q}
return q}}function makeConstList(a,b){if(b!=null)A.b(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var s=0;s<a.length;++s){convertToFastObject(a[s])}}var y=0
function instanceTearOffGetter(a,b){var s=null
return a?function(c){if(s===null)s=A.fr(b)
return new s(c,this)}:function(){if(s===null)s=A.fr(b)
return new s(this,null)}}function staticTearOffGetter(a){var s=null
return function(){if(s===null)s=A.fr(a).prototype
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
fw(a,b,c,d){return{i:a,p:b,e:c,x:d}},
ft(a){var s,r,q,p,o,n="_$dart_js",m=a[v.dispatchPropertyName]
if(m==null)if($.fu==null){A.jU()
m=a[v.dispatchPropertyName]}if(m!=null){s=m.p
if(!1===s)return m.i
if(!0===s)return a
r=Object.getPrototypeOf(a)
if(s===r)return m.i
if(m.e===r)throw A.h(A.fU("Return interceptor for "+A.o(s(a,m))))}q=a.constructor
if(q==null)p=null
else{o=$.eq
if(o==null)o=$.eq=A.eV(n)
p=q[o]}if(p!=null)return p
p=A.jY(a)
if(p!=null)return p
if(typeof a=="function")return B.A
s=Object.getPrototypeOf(a)
if(s==null)return B.n
if(s===Object.prototype)return B.n
if(typeof q=="function"){o=$.eq
if(o==null)o=$.eq=A.eV(n)
Object.defineProperty(q,o,{value:B.i,enumerable:false,writable:true,configurable:true})
return B.i}return B.i},
i6(a,b){if(a<0||a>4294967295)throw A.h(A.dS(a,0,4294967295,"length",null))
return J.i7(new Array(a),b)},
fK(a,b){if(a<0)throw A.h(A.aR("Length must be a non-negative integer: "+a,null))
return A.b(new Array(a),b.j("t<0>"))},
dF(a,b){if(a<0)throw A.h(A.aR("Length must be a non-negative integer: "+a,null))
return A.b(new Array(a),b.j("t<0>"))},
i7(a,b){var s=A.b(a,b.j("t<0>"))
s.$flags=1
return s},
fL(a){if(a<256)switch(a){case 9:case 10:case 11:case 12:case 13:case 32:case 133:case 160:return!0
default:return!1}switch(a){case 5760:case 8192:case 8193:case 8194:case 8195:case 8196:case 8197:case 8198:case 8199:case 8200:case 8201:case 8202:case 8232:case 8233:case 8239:case 8287:case 12288:case 65279:return!0
default:return!1}},
i8(a,b){var s,r
for(s=a.length;b<s;){r=a.charCodeAt(b)
if(r!==32&&r!==13&&!J.fL(r))break;++b}return b},
i9(a,b){var s,r
for(;b>0;b=s){s=b-1
r=a.charCodeAt(s)
if(r!==32&&r!==13&&!J.fL(r))break}return b},
ao(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.aY.prototype
return J.bV.prototype}if(typeof a=="string")return J.aA.prototype
if(a==null)return J.aZ.prototype
if(typeof a=="boolean")return J.bU.prototype
if(Array.isArray(a))return J.t.prototype
if(typeof a!="object"){if(typeof a=="function")return J.a1.prototype
if(typeof a=="symbol")return J.b2.prototype
if(typeof a=="bigint")return J.b0.prototype
return a}if(a instanceof A.j)return a
return J.ft(a)},
hw(a){if(typeof a=="string")return J.aA.prototype
if(a==null)return a
if(Array.isArray(a))return J.t.prototype
if(typeof a!="object"){if(typeof a=="function")return J.a1.prototype
if(typeof a=="symbol")return J.b2.prototype
if(typeof a=="bigint")return J.b0.prototype
return a}if(a instanceof A.j)return a
return J.ft(a)},
eU(a){if(a==null)return a
if(Array.isArray(a))return J.t.prototype
if(typeof a!="object"){if(typeof a=="function")return J.a1.prototype
if(typeof a=="symbol")return J.b2.prototype
if(typeof a=="bigint")return J.b0.prototype
return a}if(a instanceof A.j)return a
return J.ft(a)},
Y(a,b){if(a==null)return b==null
if(typeof a!="object")return b!=null&&a===b
return J.ao(a).D(a,b)},
hS(a,b){return J.eU(a).X(a,b)},
N(a){return J.ao(a).gm(a)},
cG(a){return J.eU(a).gq(a)},
hT(a){return J.hw(a).gB(a)},
hU(a){return J.ao(a).gn(a)},
fA(a,b,c){return J.eU(a).H(a,b,c)},
bC(a){return J.ao(a).i(a)},
hV(a,b){return J.eU(a).aM(a,b)},
bS:function bS(){},
bU:function bU(){},
aZ:function aZ(){},
b1:function b1(){},
a2:function a2(){},
cf:function cf(){},
bc:function bc(){},
a1:function a1(){},
b0:function b0(){},
b2:function b2(){},
t:function t(a){this.$ti=a},
bT:function bT(){},
dH:function dH(a){this.$ti=a},
bE:function bE(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
b_:function b_(){},
aY:function aY(){},
bV:function bV(){},
aA:function aA(){}},A={fc:function fc(){},
ib(a){return new A.b3("Field '"+a+"' has been assigned during initialization.")},
ic(a){return new A.b3("Field '"+a+"' has not been initialized.")},
a5(a,b){a=a+b&536870911
a=a+((a&524287)<<10)&536870911
return a^a>>>6},
fg(a){a=a+((a&67108863)<<3)&536870911
a^=a>>>11
return a+((a&16383)<<15)&536870911},
ht(a,b,c){return a},
fv(a){var s,r
for(s=$.am.length,r=0;r<s;++r)if(a===$.am[r])return!0
return!1},
ig(a,b,c,d){if(t.a.b(a))return new A.ad(a,b,c.j("@<0>").u(d).j("ad<1,2>"))
return new A.S(a,b,c.j("@<0>").u(d).j("S<1,2>"))},
b3:function b3(a){this.a=a},
dT:function dT(){},
i:function i(){},
R:function R(){},
aC:function aC(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
S:function S(a,b,c){this.a=a
this.b=b
this.$ti=c},
ad:function ad(a,b,c){this.a=a
this.b=b
this.$ti=c},
c2:function c2(a,b,c){var _=this
_.a=null
_.b=a
_.c=b
_.$ti=c},
T:function T(a,b,c){this.a=a
this.b=b
this.$ti=c},
W:function W(a,b,c){this.a=a
this.b=b
this.$ti=c},
cw:function cw(a,b){this.a=a
this.b=b},
aU:function aU(){},
hE(a){var s=A.hD(a)
if(s!=null)return s
return"minified:"+a},
kp(a,b){var s
if(b!=null){s=b.x
if(s!=null)return s}return t.p.b(a)},
o(a){var s
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
s=J.bC(a)
return s},
ch(a){var s,r=$.fO
if(r==null)r=$.fO=Symbol("identityHashCode")
s=a[r]
if(s==null){s=Math.random()*0x3fffffff|0
a[r]=s}return s},
il(a){var s,r
if(!/^\s*[+-]?(?:Infinity|NaN|(?:\.\d+|\d+(?:\.\d*)?)(?:[eE][+-]?\d+)?)\s*$/.test(a))return null
s=parseFloat(a)
if(isNaN(s)){r=B.d.aK(a)
if(r==="NaN"||r==="+NaN"||r==="-NaN")return s
return null}return s},
ci(a){var s,r,q,p
if(a instanceof A.j)return A.G(A.aq(a),null)
s=J.ao(a)
if(s===B.z||s===B.B||t.o.b(a)){r=B.j(a)
if(r!=="Object"&&r!=="")return r
q=a.constructor
if(typeof q=="function"){p=q.name
if(typeof p=="string"&&p!=="Object"&&p!=="")return p}}return A.G(A.aq(a),null)},
fP(a){var s,r,q
if(a==null||typeof a=="number"||A.eO(a))return J.bC(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.Z)return a.i(0)
if(a instanceof A.bm)return a.aw(!0)
s=$.hR()
for(r=0;r<1;++r){q=s[r].bH(a)
if(q!=null)return q}return"Instance of '"+A.ci(a)+"'"},
ii(){return Date.now()},
ik(){var s,r
if($.dQ!==0)return
$.dQ=1000
if(typeof window=="undefined")return
s=window
if(s==null)return
if(!!s.dartUseDateNowForTicks)return
r=s.performance
if(r==null)return
if(typeof r.now!="function")return
$.dQ=1e6
$.dR=new A.dP(r)},
ij(a){var s=a.$thrownJsError
if(s==null)return null
return A.ap(s)},
jJ(a){return new A.O(!0,a,null,null)},
h(a){return A.B(a,new Error())},
B(a,b){var s
if(a==null)a=new A.U()
b.dartException=a
s=A.k5
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:s})
b.name=""}else b.toString=s
return b},
k5(){return J.bC(this.dartException)},
f4(a,b){throw A.B(a,b==null?new Error():b)},
k4(a,b,c){var s
if(b==null)b=0
if(c==null)c=0
s=Error()
A.f4(A.j7(a,b,c),s)},
j7(a,b,c){var s,r,q,p,o,n,m,l,k
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
return new A.bd("'"+s+"': Cannot "+o+" "+l+k+n)},
M(a){throw A.h(A.Q(a))},
V(a){var s,r,q,p,o,n
a=A.k2(a.replace(String({}),"$receiver$"))
s=a.match(/\\\$[a-zA-Z]+\\\$/g)
if(s==null)s=A.b([],t.s)
r=s.indexOf("\\$arguments\\$")
q=s.indexOf("\\$argumentsExpr\\$")
p=s.indexOf("\\$expr\\$")
o=s.indexOf("\\$method\\$")
n=s.indexOf("\\$receiver\\$")
return new A.e5(a.replace(new RegExp("\\\\\\$arguments\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$argumentsExpr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$expr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$method\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$receiver\\\\\\$","g"),"((?:x|[^x])*)"),r,q,p,o,n)},
e6(a){return function($expr$){var $argumentsExpr$="$arguments$"
try{$expr$.$method$($argumentsExpr$)}catch(s){return s.message}}(a)},
fT(a){return function($expr$){try{$expr$.$method$}catch(s){return s.message}}(a)},
fd(a,b){var s=b==null,r=s?null:b.method
return new A.bW(a,r,s?null:b.receiver)},
ac(a){if(a==null)return new A.dN(a)
if(a instanceof A.bL)return A.aa(a,a.a)
if(typeof a!=="object")return a
if("dartException" in a)return A.aa(a,a.dartException)
return A.jH(a)},
aa(a,b){if(t.Q.b(b))if(b.$thrownJsError==null)b.$thrownJsError=a
return b},
jH(a){var s,r,q,p,o,n,m,l,k,j,i,h,g
if(!("message" in a))return a
s=a.message
if("number" in a&&typeof a.number=="number"){r=a.number
q=r&65535
if((B.b.bd(r,16)&8191)===10)switch(q){case 438:return A.aa(a,A.fd(A.o(s)+" (Error "+q+")",null))
case 445:case 5007:A.o(s)
return A.aa(a,new A.b8())}}if(a instanceof TypeError){p=$.hH()
o=$.hI()
n=$.hJ()
m=$.hK()
l=$.hN()
k=$.hO()
j=$.hM()
$.hL()
i=$.hQ()
h=$.hP()
g=p.v(s)
if(g!=null)return A.aa(a,A.fd(s,g))
else{g=o.v(s)
if(g!=null){g.method="call"
return A.aa(a,A.fd(s,g))}else if(n.v(s)!=null||m.v(s)!=null||l.v(s)!=null||k.v(s)!=null||j.v(s)!=null||m.v(s)!=null||i.v(s)!=null||h.v(s)!=null)return A.aa(a,new A.b8())}return A.aa(a,new A.cv(typeof s=="string"?s:""))}if(a instanceof RangeError){if(typeof s=="string"&&s.indexOf("call stack")!==-1)return new A.bb()
s=function(b){try{return String(b)}catch(f){}return null}(a)
return A.aa(a,new A.O(!1,null,null,typeof s=="string"?s.replace(/^RangeError:\s*/,""):s))}if(typeof InternalError=="function"&&a instanceof InternalError)if(typeof s=="string"&&s==="too much recursion")return new A.bb()
return a},
ap(a){var s
if(a instanceof A.bL)return a.b
if(a==null)return new A.bp(a)
s=a.$cachedTrace
if(s!=null)return s
s=new A.bp(a)
if(typeof a==="object")a.$cachedTrace=s
return s},
f3(a){if(a==null)return J.N(a)
if(typeof a=="object")return A.ch(a)
return J.N(a)},
jR(a,b){var s,r,q,p=a.length
for(s=0;s<p;s=q){r=s+1
q=r+1
b.t(0,a[s],a[r])}return b},
jg(a,b,c,d,e,f){switch(b){case 0:return a.$0()
case 1:return a.$1(c)
case 2:return a.$2(c,d)
case 3:return a.$3(c,d,e)
case 4:return a.$4(c,d,e,f)}throw A.h(A.fH("Unsupported number of arguments for wrapped closure"))},
cF(a,b){var s=a.$identity
if(!!s)return s
s=A.jN(a,b)
a.$identity=s
return s},
jN(a,b){var s
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
return function(c,d,e){return function(f,g,h,i){return e(c,d,f,g,h,i)}}(a,b,A.jg)},
i2(a2){var s,r,q,p,o,n,m,l,k,j,i=a2.co,h=a2.iS,g=a2.iI,f=a2.nDA,e=a2.aI,d=a2.fs,c=a2.cs,b=d[0],a=c[0],a0=i[b],a1=a2.fT
a1.toString
s=h?Object.create(new A.cr().constructor.prototype):Object.create(new A.au(null,null).constructor.prototype)
s.$initialize=s.constructor
r=h?function static_tear_off(){this.$initialize()}:function tear_off(a3,a4){this.$initialize(a3,a4)}
s.constructor=r
r.prototype=s
s.$_name=b
s.$_target=a0
q=!h
if(q)p=A.fG(b,a0,g,f)
else{s.$static_name=b
p=a0}s.$S=A.hZ(a1,h,g)
s[a]=p
for(o=p,n=1;n<d.length;++n){m=d[n]
if(typeof m=="string"){l=i[m]
k=m
m=l}else k=""
j=c[n]
if(j!=null){if(q)m=A.fG(k,m,g,f)
s[j]=m}if(n===e)o=m}s.$C=o
s.$R=a2.rC
s.$D=a2.dV
return r},
hZ(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.h("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.hW)}throw A.h("Error in functionType of tearoff")},
i_(a,b,c,d){var s=A.fF
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,s)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,s)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,s)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,s)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,s)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,s)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,s)}},
fG(a,b,c,d){if(c)return A.i1(a,b,d)
return A.i_(b.length,d,a,b)},
i0(a,b,c,d){var s=A.fF,r=A.hX
switch(b?-1:a){case 0:throw A.h(new A.cl("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,r,s)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,r,s)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,r,s)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,r,s)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,r,s)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,r,s)
default:return function(e,f,g){return function(){var q=[g(this)]
Array.prototype.push.apply(q,arguments)
return e.apply(f(this),q)}}(d,r,s)}},
i1(a,b,c){var s,r
if($.fD==null)$.fD=A.fC("interceptor")
if($.fE==null)$.fE=A.fC("receiver")
s=b.length
r=A.i0(s,c,a,b)
return r},
fr(a){return A.i2(a)},
hW(a,b){return A.bv(v.typeUniverse,A.aq(a.a),b)},
fF(a){return a.a},
hX(a){return a.b},
fC(a){var s,r,q,p=new A.au("receiver","interceptor"),o=Object.getOwnPropertyNames(p)
o.$flags=1
s=o
for(o=s.length,r=0;r<o;++r){q=s[r]
if(p[q]===a)return q}throw A.h(A.aR("Field name "+a+" not found.",null))},
eV(a){return v.getIsolateTag(a)},
jY(a){var s,r,q,p,o,n=$.hy.$1(a),m=$.eS[n]
if(m!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}s=$.eZ[n]
if(s!=null)return s
r=v.interceptorsByTag[n]
if(r==null){q=$.hr.$2(a,n)
if(q!=null){m=$.eS[q]
if(m!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}s=$.eZ[q]
if(s!=null)return s
r=v.interceptorsByTag[q]
n=q}}if(r==null)return null
s=r.prototype
p=n[0]
if(p==="!"){m=A.f2(s)
$.eS[n]=m
Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}if(p==="~"){$.eZ[n]=s
return s}if(p==="-"){o=A.f2(s)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:o,enumerable:false,writable:true,configurable:true})
return o.i}if(p==="+")return A.hA(a,s)
if(p==="*")throw A.h(A.fU(n))
if(v.leafTags[n]===true){o=A.f2(s)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:o,enumerable:false,writable:true,configurable:true})
return o.i}else return A.hA(a,s)},
hA(a,b){var s=Object.getPrototypeOf(a)
Object.defineProperty(s,v.dispatchPropertyName,{value:J.fw(b,s,null,null),enumerable:false,writable:true,configurable:true})
return b},
f2(a){return J.fw(a,!1,null,!!a.$iF)},
k_(a,b,c){var s=b.prototype
if(v.leafTags[a]===true)return A.f2(s)
else return J.fw(s,c,null,null)},
jU(){if(!0===$.fu)return
$.fu=!0
A.jV()},
jV(){var s,r,q,p,o,n,m,l
$.eS=Object.create(null)
$.eZ=Object.create(null)
A.jT()
s=v.interceptorsByTag
r=Object.getOwnPropertyNames(s)
if(typeof window!="undefined"){window
q=function(){}
for(p=0;p<r.length;++p){o=r[p]
n=$.hC.$1(o)
if(n!=null){m=A.k_(o,s[o],n)
if(m!=null){Object.defineProperty(n,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
q.prototype=n}}}}for(p=0;p<r.length;++p){o=r[p]
if(/^[A-Za-z_]/.test(o)){l=s[o]
s["!"+o]=l
s["~"+o]=l
s["-"+o]=l
s["+"+o]=l
s["*"+o]=l}}},
jT(){var s,r,q,p,o,n,m=B.o()
m=A.aP(B.p,A.aP(B.q,A.aP(B.k,A.aP(B.k,A.aP(B.r,A.aP(B.t,A.aP(B.u(B.j),m)))))))
if(typeof dartNativeDispatchHooksTransformer!="undefined"){s=dartNativeDispatchHooksTransformer
if(typeof s=="function")s=[s]
if(Array.isArray(s))for(r=0;r<s.length;++r){q=s[r]
if(typeof q=="function")m=q(m)||m}}p=m.getTag
o=m.getUnknownTag
n=m.prototypeForTag
$.hy=new A.eW(p)
$.hr=new A.eX(o)
$.hC=new A.eY(n)},
aP(a,b){return a(b)||b},
jO(a,b){var s=b.length,r=v.rttc[""+s+";"+a]
if(r==null)return null
if(s===0)return r
if(s===r.length)return r.apply(null,b)
return r(b)},
ia(a,b,c,d,e,f){var s=b?"m":"",r=c?"":"i",q=d?"u":"",p=e?"s":"",o=function(g,h){try{return new RegExp(g,h)}catch(n){return n}}(a,s+r+q+p+f)
if(o instanceof RegExp)return o
throw A.h(A.fI("Illegal RegExp pattern ("+String(o)+")",a))},
k2(a){if(/[[\]{}()*+?.\\^$|]/.test(a))return a.replace(/[[\]{}()*+?.\\^$|]/g,"\\$&")
return a},
a6:function a6(a,b,c){this.a=a
this.b=b
this.c=c},
dP:function dP(a){this.a=a},
b9:function b9(){},
e5:function e5(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
b8:function b8(){},
bW:function bW(a,b,c){this.a=a
this.b=b
this.c=c},
cv:function cv(a){this.a=a},
dN:function dN(a){this.a=a},
bL:function bL(){},
bp:function bp(a){this.a=a
this.b=null},
Z:function Z(){},
bH:function bH(){},
bI:function bI(){},
ct:function ct(){},
cr:function cr(){},
au:function au(a,b){this.a=a
this.b=b},
cl:function cl(a){this.a=a},
af:function af(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
dI:function dI(a,b){var _=this
_.a=a
_.b=b
_.d=_.c=null},
ah:function ah(a,b){this.a=a
this.$ti=b},
bY:function bY(a,b,c){var _=this
_.a=a
_.b=b
_.c=c
_.d=null},
bZ:function bZ(a,b,c){var _=this
_.a=a
_.b=b
_.c=c
_.d=null},
ag:function ag(a,b){this.a=a
this.$ti=b},
bX:function bX(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
eW:function eW(a){this.a=a},
eX:function eX(a){this.a=a},
eY:function eY(a){this.a=a},
bm:function bm(){},
cC:function cC(){},
dG:function dG(a,b){var _=this
_.a=a
_.b=b
_.e=_.d=_.c=null},
aD:function aD(){},
b6:function b6(){},
c3:function c3(){},
aE:function aE(){},
b4:function b4(){},
b5:function b5(){},
c4:function c4(){},
c5:function c5(){},
c6:function c6(){},
c7:function c7(){},
c8:function c8(){},
c9:function c9(){},
ca:function ca(){},
b7:function b7(){},
cb:function cb(){},
bi:function bi(){},
bj:function bj(){},
bk:function bk(){},
bl:function bl(){},
fe(a,b){var s=b.c
return s==null?b.c=A.bt(a,"aX",[b.x]):s},
fQ(a){var s=a.w
if(s===6||s===7)return A.fQ(a.x)
return s===11||s===12},
ip(a){return a.as},
eT(a){return A.eA(v.typeUniverse,a,!1)},
al(a1,a2,a3,a4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=a2.w
switch(a0){case 5:case 1:case 2:case 3:case 4:return a2
case 6:s=a2.x
r=A.al(a1,s,a3,a4)
if(r===s)return a2
return A.h3(a1,r,!0)
case 7:s=a2.x
r=A.al(a1,s,a3,a4)
if(r===s)return a2
return A.h2(a1,r,!0)
case 8:q=a2.y
p=A.aO(a1,q,a3,a4)
if(p===q)return a2
return A.bt(a1,a2.x,p)
case 9:o=a2.x
n=A.al(a1,o,a3,a4)
m=a2.y
l=A.aO(a1,m,a3,a4)
if(n===o&&l===m)return a2
return A.fk(a1,n,l)
case 10:k=a2.x
j=a2.y
i=A.aO(a1,j,a3,a4)
if(i===j)return a2
return A.h4(a1,k,i)
case 11:h=a2.x
g=A.al(a1,h,a3,a4)
f=a2.y
e=A.jE(a1,f,a3,a4)
if(g===h&&e===f)return a2
return A.h1(a1,g,e)
case 12:d=a2.y
a4+=d.length
c=A.aO(a1,d,a3,a4)
o=a2.x
n=A.al(a1,o,a3,a4)
if(c===d&&n===o)return a2
return A.fl(a1,n,c,!0)
case 13:b=a2.x
if(b<a4)return a2
a=a3[b-a4]
if(a==null)return a2
return a
default:throw A.h(A.bG("Attempted to substitute unexpected RTI kind "+a0))}},
aO(a,b,c,d){var s,r,q,p,o=b.length,n=A.eB(o)
for(s=!1,r=0;r<o;++r){q=b[r]
p=A.al(a,q,c,d)
if(p!==q)s=!0
n[r]=p}return s?n:b},
jF(a,b,c,d){var s,r,q,p,o,n,m=b.length,l=A.eB(m)
for(s=!1,r=0;r<m;r+=3){q=b[r]
p=b[r+1]
o=b[r+2]
n=A.al(a,o,c,d)
if(n!==o)s=!0
l.splice(r,3,q,p,n)}return s?l:b},
jE(a,b,c,d){var s,r=b.a,q=A.aO(a,r,c,d),p=b.b,o=A.aO(a,p,c,d),n=b.c,m=A.jF(a,n,c,d)
if(q===r&&o===p&&m===n)return b
s=new A.cz()
s.a=q
s.b=o
s.c=m
return s},
b(a,b){a[v.arrayRti]=b
return a},
hu(a){var s=a.$S
if(s!=null){if(typeof s=="number")return A.jS(s)
return a.$S()}return null},
jW(a,b){var s
if(A.fQ(b))if(a instanceof A.Z){s=A.hu(a)
if(s!=null)return s}return A.aq(a)},
aq(a){if(a instanceof A.j)return A.a8(a)
if(Array.isArray(a))return A.cE(a)
return A.fo(J.ao(a))},
cE(a){var s=a[v.arrayRti],r=t.b
if(s==null)return r
if(s.constructor!==r.constructor)return r
return s},
a8(a){var s=a.$ti
return s!=null?s:A.fo(a)},
fo(a){var s=a.constructor,r=s.$ccache
if(r!=null)return r
return A.je(a,s)},
je(a,b){var s=a instanceof A.Z?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,r=A.iR(v.typeUniverse,s.name)
b.$ccache=r
return r},
jS(a){var s,r=v.types,q=r[a]
if(typeof q=="string"){s=A.eA(v.typeUniverse,q,!1)
r[a]=s
return s}return q},
hx(a){return A.an(A.a8(a))},
fq(a){var s
if(a instanceof A.bm)return A.jQ(a.$r,a.an())
s=a instanceof A.Z?A.hu(a):null
if(s!=null)return s
if(t.bW.b(a))return J.hU(a).a
if(Array.isArray(a))return A.cE(a)
return A.aq(a)},
an(a){var s=a.r
return s==null?a.r=new A.ez(a):s},
jQ(a,b){var s,r,q=b,p=q.length
if(p===0)return t.F
s=A.bv(v.typeUniverse,A.fq(q[0]),"@<0>")
for(r=1;r<p;++r)s=A.h6(v.typeUniverse,s,A.fq(q[r]))
return A.bv(v.typeUniverse,s,a)},
L(a){return A.an(A.eA(v.typeUniverse,a,!1))},
jd(a){var s=this
s.b=A.jC(s)
return s.b(a)},
jC(a){var s,r,q,p
if(a===t.K)return A.jn
if(A.ar(a))return A.jr
s=a.w
if(s===6)return A.jb
if(s===1)return A.hi
if(s===7)return A.jh
r=A.jB(a)
if(r!=null)return r
if(s===8){q=a.x
if(a.y.every(A.ar)){a.f="$i"+q
if(q==="k")return A.jl
if(a===t.m)return A.jk
return A.jq}}else if(s===10){p=A.jO(a.x,a.y)
return p==null?A.hi:p}return A.j9},
jB(a){if(a.w===8){if(a===t.S)return A.ji
if(a===t.i||a===t.H)return A.jm
if(a===t.N)return A.jp
if(a===t.y)return A.eO}return null},
jc(a){var s=this,r=A.j8
if(A.ar(s))r=A.j2
else if(s===t.K)r=A.j0
else if(A.aQ(s)){r=A.ja
if(s===t.a3)r=A.iX
else if(s===t.u)r=A.j1
else if(s===t.cG)r=A.iT
else if(s===t.be)r=A.j_
else if(s===t.I)r=A.iV
else if(s===t.aQ)r=A.iY}else if(s===t.S)r=A.iW
else if(s===t.N)r=A.hb
else if(s===t.y)r=A.ha
else if(s===t.H)r=A.iZ
else if(s===t.i)r=A.iU
else if(s===t.m)r=A.aM
s.a=r
return s.a(a)},
j9(a){var s=this
if(a==null)return A.aQ(s)
return A.jX(v.typeUniverse,A.jW(a,s),s)},
jb(a){if(a==null)return!0
return this.x.b(a)},
jq(a){var s,r=this
if(a==null)return A.aQ(r)
s=r.f
if(a instanceof A.j)return!!a[s]
return!!J.ao(a)[s]},
jl(a){var s,r=this
if(a==null)return A.aQ(r)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
s=r.f
if(a instanceof A.j)return!!a[s]
return!!J.ao(a)[s]},
jk(a){var s=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.j)return!!a[s.f]
return!0}if(typeof a=="function")return!0
return!1},
hh(a){if(typeof a=="object"){if(a instanceof A.j)return t.m.b(a)
return!0}if(typeof a=="function")return!0
return!1},
j8(a){var s=this
if(a==null){if(A.aQ(s))return a}else if(s.b(a))return a
throw A.B(A.he(a,s),new Error())},
ja(a){var s=this
if(a==null||s.b(a))return a
throw A.B(A.he(a,s),new Error())},
he(a,b){return new A.br("TypeError: "+A.fV(a,A.G(b,null)))},
fV(a,b){return A.d0(a)+": type '"+A.G(A.fq(a),null)+"' is not a subtype of type '"+b+"'"},
I(a,b){return new A.br("TypeError: "+A.fV(a,b))},
jh(a){var s=this
return s.x.b(a)||A.fe(v.typeUniverse,s).b(a)},
jn(a){return a!=null},
j0(a){if(a!=null)return a
throw A.B(A.I(a,"Object"),new Error())},
jr(a){return!0},
j2(a){return a},
hi(a){return!1},
eO(a){return!0===a||!1===a},
ha(a){if(!0===a)return!0
if(!1===a)return!1
throw A.B(A.I(a,"bool"),new Error())},
iT(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.B(A.I(a,"bool?"),new Error())},
iU(a){if(typeof a=="number")return a
throw A.B(A.I(a,"double"),new Error())},
iV(a){if(typeof a=="number")return a
if(a==null)return a
throw A.B(A.I(a,"double?"),new Error())},
ji(a){return typeof a=="number"&&Math.floor(a)===a},
iW(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.B(A.I(a,"int"),new Error())},
iX(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.B(A.I(a,"int?"),new Error())},
jm(a){return typeof a=="number"},
iZ(a){if(typeof a=="number")return a
throw A.B(A.I(a,"num"),new Error())},
j_(a){if(typeof a=="number")return a
if(a==null)return a
throw A.B(A.I(a,"num?"),new Error())},
jp(a){return typeof a=="string"},
hb(a){if(typeof a=="string")return a
throw A.B(A.I(a,"String"),new Error())},
j1(a){if(typeof a=="string")return a
if(a==null)return a
throw A.B(A.I(a,"String?"),new Error())},
aM(a){if(A.hh(a))return a
throw A.B(A.I(a,"JSObject"),new Error())},
iY(a){if(a==null)return a
if(A.hh(a))return a
throw A.B(A.I(a,"JSObject?"),new Error())},
hp(a,b){var s,r,q
for(s="",r="",q=0;q<a.length;++q,r=", ")s+=r+A.G(a[q],b)
return s},
jx(a,b){var s,r,q,p,o,n,m=a.x,l=a.y
if(""===m)return"("+A.hp(l,b)+")"
s=l.length
r=m.split(",")
q=r.length-s
for(p="(",o="",n=0;n<s;++n,o=", "){p+=o
if(q===0)p+="{"
p+=A.G(l[n],b)
if(q>=0)p+=" "+r[q];++q}return p+"})"},
hf(a1,a2,a3){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a=", ",a0=null
if(a3!=null){s=a3.length
if(a2==null)a2=A.b([],t.s)
else a0=a2.length
r=a2.length
for(q=s;q>0;--q)a2.push("T"+(r+q))
for(p=t.X,o="<",n="",q=0;q<s;++q,n=a){o=o+n+a2[a2.length-1-q]
m=a3[q]
l=m.w
if(!(l===2||l===3||l===4||l===5||m===p))o+=" extends "+A.G(m,a2)}o+=">"}else o=""
p=a1.x
k=a1.y
j=k.a
i=j.length
h=k.b
g=h.length
f=k.c
e=f.length
d=A.G(p,a2)
for(c="",b="",q=0;q<i;++q,b=a)c+=b+A.G(j[q],a2)
if(g>0){c+=b+"["
for(b="",q=0;q<g;++q,b=a)c+=b+A.G(h[q],a2)
c+="]"}if(e>0){c+=b+"{"
for(b="",q=0;q<e;q+=3,b=a){c+=b
if(f[q+1])c+="required "
c+=A.G(f[q+2],a2)+" "+f[q]}c+="}"}if(a0!=null){a2.toString
a2.length=a0}return o+"("+c+") => "+d},
G(a,b){var s,r,q,p,o,n,m=a.w
if(m===5)return"erased"
if(m===2)return"dynamic"
if(m===3)return"void"
if(m===1)return"Never"
if(m===4)return"any"
if(m===6){s=a.x
r=A.G(s,b)
q=s.w
return(q===11||q===12?"("+r+")":r)+"?"}if(m===7)return"FutureOr<"+A.G(a.x,b)+">"
if(m===8){p=A.jG(a.x)
o=a.y
return o.length>0?p+("<"+A.hp(o,b)+">"):p}if(m===10)return A.jx(a,b)
if(m===11)return A.hf(a,b,null)
if(m===12)return A.hf(a.x,b,a.y)
if(m===13){n=a.x
return b[b.length-1-n]}return"?"},
jG(a){var s=A.hD(a)
if(s!=null)return s
return"minified:"+a},
iS(a,b){var s=a.tR[b]
while(typeof s=="string")s=a.tR[s]
return s},
iR(a,b){var s,r,q,p,o,n=a.eT,m=n[b]
if(m==null)return A.eA(a,b,!1)
else if(typeof m=="number"){s=m
r=A.bu(a,5,"#")
q=A.eB(s)
for(p=0;p<s;++p)q[p]=r
o=A.bt(a,b,q)
n[b]=o
return o}else return m},
iQ(a,b){return A.h7(a.tR,b)},
iP(a,b){return A.h7(a.eT,b)},
eA(a,b,c){var s,r=a.eC,q=r.get(b)
if(q!=null)return q
s=A.h5(a,null,b,!1)
r.set(b,s)
return s},
bv(a,b,c){var s,r,q=b.z
if(q==null)q=b.z=new Map()
s=q.get(c)
if(s!=null)return s
r=A.h5(a,b,c,!0)
q.set(c,r)
return r},
h6(a,b,c){var s,r,q,p=b.Q
if(p==null)p=b.Q=new Map()
s=c.as
r=p.get(s)
if(r!=null)return r
q=A.fk(a,b,c.w===9?c.y:[c])
p.set(s,q)
return q},
h5(a,b,c,d){return A.iG(A.iA(a,b,c,d))},
a7(a,b){b.a=A.jc
b.b=A.jd
return b},
bu(a,b,c){var s,r,q=a.eC.get(c)
if(q!=null)return q
s=new A.J(null,null)
s.w=b
s.as=c
r=A.a7(a,s)
a.eC.set(c,r)
return r},
h3(a,b,c){var s,r=b.as+"?",q=a.eC.get(r)
if(q!=null)return q
s=A.iN(a,b,r,c)
a.eC.set(r,s)
return s},
iN(a,b,c,d){var s,r,q
if(d){s=b.w
r=!0
if(!A.ar(b))if(!(b===t.P||b===t.T))if(s!==6)r=s===7&&A.aQ(b.x)
if(r)return b
else if(s===1)return t.P}q=new A.J(null,null)
q.w=6
q.x=b
q.as=c
return A.a7(a,q)},
h2(a,b,c){var s,r=b.as+"/",q=a.eC.get(r)
if(q!=null)return q
s=A.iL(a,b,r,c)
a.eC.set(r,s)
return s},
iL(a,b,c,d){var s,r
if(d){s=b.w
if(A.ar(b)||b===t.K)return b
else if(s===1)return A.bt(a,"aX",[b])
else if(b===t.P||b===t.T)return t.bc}r=new A.J(null,null)
r.w=7
r.x=b
r.as=c
return A.a7(a,r)},
iO(a,b){var s,r,q=""+b+"^",p=a.eC.get(q)
if(p!=null)return p
s=new A.J(null,null)
s.w=13
s.x=b
s.as=q
r=A.a7(a,s)
a.eC.set(q,r)
return r},
bs(a){var s,r,q,p=a.length
for(s="",r="",q=0;q<p;++q,r=",")s+=r+a[q].as
return s},
iK(a){var s,r,q,p,o,n=a.length
for(s="",r="",q=0;q<n;q+=3,r=","){p=a[q]
o=a[q+1]?"!":":"
s+=r+p+o+a[q+2].as}return s},
bt(a,b,c){var s,r,q,p=b
if(c.length>0)p+="<"+A.bs(c)+">"
s=a.eC.get(p)
if(s!=null)return s
r=new A.J(null,null)
r.w=8
r.x=b
r.y=c
if(c.length>0)r.c=c[0]
r.as=p
q=A.a7(a,r)
a.eC.set(p,q)
return q},
fk(a,b,c){var s,r,q,p,o,n
if(b.w===9){s=b.x
r=b.y.concat(c)}else{r=c
s=b}q=s.as+(";<"+A.bs(r)+">")
p=a.eC.get(q)
if(p!=null)return p
o=new A.J(null,null)
o.w=9
o.x=s
o.y=r
o.as=q
n=A.a7(a,o)
a.eC.set(q,n)
return n},
h4(a,b,c){var s,r,q="+"+(b+"("+A.bs(c)+")"),p=a.eC.get(q)
if(p!=null)return p
s=new A.J(null,null)
s.w=10
s.x=b
s.y=c
s.as=q
r=A.a7(a,s)
a.eC.set(q,r)
return r},
h1(a,b,c){var s,r,q,p,o,n=b.as,m=c.a,l=m.length,k=c.b,j=k.length,i=c.c,h=i.length,g="("+A.bs(m)
if(j>0){s=l>0?",":""
g+=s+"["+A.bs(k)+"]"}if(h>0){s=l>0?",":""
g+=s+"{"+A.iK(i)+"}"}r=n+(g+")")
q=a.eC.get(r)
if(q!=null)return q
p=new A.J(null,null)
p.w=11
p.x=b
p.y=c
p.as=r
o=A.a7(a,p)
a.eC.set(r,o)
return o},
fl(a,b,c,d){var s,r=b.as+("<"+A.bs(c)+">"),q=a.eC.get(r)
if(q!=null)return q
s=A.iM(a,b,c,r,d)
a.eC.set(r,s)
return s},
iM(a,b,c,d,e){var s,r,q,p,o,n,m,l
if(e){s=c.length
r=A.eB(s)
for(q=0,p=0;p<s;++p){o=c[p]
if(o.w===1){r[p]=o;++q}}if(q>0){n=A.al(a,b,r,0)
m=A.aO(a,c,r,0)
return A.fl(a,n,m,c!==m)}}l=new A.J(null,null)
l.w=12
l.x=b
l.y=c
l.as=d
return A.a7(a,l)},
iA(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
iG(a){var s,r,q,p,o,n,m,l=a.r,k=a.s
for(s=l.length,r=0;r<s;){q=l.charCodeAt(r)
if(q>=48&&q<=57)r=A.iC(r+1,q,l,k)
else if((((q|32)>>>0)-97&65535)<26||q===95||q===36||q===124)r=A.h_(a,r,l,k,!1)
else if(q===46)r=A.h_(a,r,l,k,!0)
else{++r
switch(q){case 44:break
case 58:k.push(!1)
break
case 33:k.push(!0)
break
case 59:k.push(A.ak(a.u,a.e,k.pop()))
break
case 94:k.push(A.iO(a.u,k.pop()))
break
case 35:k.push(A.bu(a.u,5,"#"))
break
case 64:k.push(A.bu(a.u,2,"@"))
break
case 126:k.push(A.bu(a.u,3,"~"))
break
case 60:k.push(a.p)
a.p=k.length
break
case 62:A.iE(a,k)
break
case 38:A.iD(a,k)
break
case 63:p=a.u
k.push(A.h3(p,A.ak(p,a.e,k.pop()),a.n))
break
case 47:p=a.u
k.push(A.h2(p,A.ak(p,a.e,k.pop()),a.n))
break
case 40:k.push(-3)
k.push(a.p)
a.p=k.length
break
case 41:A.iB(a,k)
break
case 91:k.push(a.p)
a.p=k.length
break
case 93:o=k.splice(a.p)
A.h0(a.u,a.e,o)
a.p=k.pop()
k.push(o)
k.push(-1)
break
case 123:k.push(a.p)
a.p=k.length
break
case 125:o=k.splice(a.p)
A.iH(a.u,a.e,o)
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
return A.ak(a.u,a.e,m)},
iC(a,b,c,d){var s,r,q=b-48
for(s=c.length;a<s;++a){r=c.charCodeAt(a)
if(!(r>=48&&r<=57))break
q=q*10+(r-48)}d.push(q)
return a},
h_(a,b,c,d,e){var s,r,q,p,o,n,m=b+1
for(s=c.length;m<s;++m){r=c.charCodeAt(m)
if(r===46){if(e)break
e=!0}else{if(!((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124))q=r>=48&&r<=57
else q=!0
if(!q)break}}p=c.substring(b,m)
if(e){s=a.u
o=a.e
if(o.w===9)o=o.x
n=A.iS(s,o.x)[p]
if(n==null)A.f4('No "'+p+'" in "'+A.ip(o)+'"')
d.push(A.bv(s,o,n))}else d.push(p)
return m},
iE(a,b){var s,r=a.u,q=A.fZ(a,b),p=b.pop()
if(typeof p=="string")b.push(A.bt(r,p,q))
else{s=A.ak(r,a.e,p)
switch(s.w){case 11:b.push(A.fl(r,s,q,a.n))
break
default:b.push(A.fk(r,s,q))
break}}},
iB(a,b){var s,r,q,p=a.u,o=b.pop(),n=null,m=null
if(typeof o=="number")switch(o){case-1:n=b.pop()
break
case-2:m=b.pop()
break
default:b.push(o)
break}else b.push(o)
s=A.fZ(a,b)
o=b.pop()
switch(o){case-3:o=b.pop()
if(n==null)n=p.sEA
if(m==null)m=p.sEA
r=A.ak(p,a.e,o)
q=new A.cz()
q.a=s
q.b=n
q.c=m
b.push(A.h1(p,r,q))
return
case-4:b.push(A.h4(p,b.pop(),s))
return
default:throw A.h(A.bG("Unexpected state under `()`: "+A.o(o)))}},
iD(a,b){var s=b.pop()
if(0===s){b.push(A.bu(a.u,1,"0&"))
return}if(1===s){b.push(A.bu(a.u,4,"1&"))
return}throw A.h(A.bG("Unexpected extended operation "+A.o(s)))},
fZ(a,b){var s=b.splice(a.p)
A.h0(a.u,a.e,s)
a.p=b.pop()
return s},
ak(a,b,c){if(typeof c=="string")return A.bt(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.iF(a,b,c)}else return c},
h0(a,b,c){var s,r=c.length
for(s=0;s<r;++s)c[s]=A.ak(a,b,c[s])},
iH(a,b,c){var s,r=c.length
for(s=2;s<r;s+=3)c[s]=A.ak(a,b,c[s])},
iF(a,b,c){var s,r,q=b.w
if(q===9){if(c===0)return b.x
s=b.y
r=s.length
if(c<=r)return s[c-1]
c-=r
b=b.x
q=b.w}else if(c===0)return b
if(q!==8)throw A.h(A.bG("Indexed base must be an interface type"))
s=b.y
if(c<=s.length)return s[c-1]
throw A.h(A.bG("Bad index "+c+" for "+b.i(0)))},
jX(a,b,c){var s,r=b.d
if(r==null)r=b.d=new Map()
s=r.get(c)
if(s==null){s=A.z(a,b,null,c,null)
r.set(c,s)}return s},
z(a,b,c,d,e){var s,r,q,p,o,n,m,l,k,j,i
if(b===d)return!0
if(A.ar(d))return!0
s=b.w
if(s===4)return!0
if(A.ar(b))return!1
if(b.w===1)return!0
r=s===13
if(r)if(A.z(a,c[b.x],c,d,e))return!0
q=d.w
p=t.P
if(b===p||b===t.T){if(q===7)return A.z(a,b,c,d.x,e)
return d===p||d===t.T||q===6}if(d===t.K){if(s===7)return A.z(a,b.x,c,d,e)
return s!==6}if(s===7){if(!A.z(a,b.x,c,d,e))return!1
return A.z(a,A.fe(a,b),c,d,e)}if(s===6)return A.z(a,p,c,d,e)&&A.z(a,b.x,c,d,e)
if(q===7){if(A.z(a,b,c,d.x,e))return!0
return A.z(a,b,c,A.fe(a,d),e)}if(q===6)return A.z(a,b,c,p,e)||A.z(a,b,c,d.x,e)
if(r)return!1
p=s!==11
if((!p||s===12)&&d===t.Z)return!0
o=s===10
if(o&&d===t.L)return!0
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
if(!A.z(a,j,c,i,e)||!A.z(a,i,e,j,c))return!1}return A.hg(a,b.x,c,d.x,e)}if(q===11){if(b===t.g)return!0
if(p)return!1
return A.hg(a,b,c,d,e)}if(s===8){if(q!==8)return!1
return A.jj(a,b,c,d,e)}if(o&&q===10)return A.jo(a,b,c,d,e)
return!1},
hg(a3,a4,a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2
if(!A.z(a3,a4.x,a5,a6.x,a7))return!1
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
if(!A.z(a3,p[h],a7,g,a5))return!1}for(h=0;h<m;++h){g=l[h]
if(!A.z(a3,p[o+h],a7,g,a5))return!1}for(h=0;h<i;++h){g=l[m+h]
if(!A.z(a3,k[h],a7,g,a5))return!1}f=s.c
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
if(!A.z(a3,e[a+2],a7,g,a5))return!1
break}}while(b<d){if(f[b+1])return!1
b+=3}return!0},
jj(a,b,c,d,e){var s,r,q,p,o,n=b.x,m=d.x
while(n!==m){s=a.tR[n]
if(s==null)return!1
if(typeof s=="string"){n=s
continue}r=s[m]
if(r==null)return!1
q=r.length
p=q>0?new Array(q):v.typeUniverse.sEA
for(o=0;o<q;++o)p[o]=A.bv(a,b,r[o])
return A.h9(a,p,null,c,d.y,e)}return A.h9(a,b.y,null,c,d.y,e)},
h9(a,b,c,d,e,f){var s,r=b.length
for(s=0;s<r;++s)if(!A.z(a,b[s],d,e[s],f))return!1
return!0},
jo(a,b,c,d,e){var s,r=b.y,q=d.y,p=r.length
if(p!==q.length)return!1
if(b.x!==d.x)return!1
for(s=0;s<p;++s)if(!A.z(a,r[s],c,q[s],e))return!1
return!0},
aQ(a){var s=a.w,r=!0
if(!(a===t.P||a===t.T))if(!A.ar(a))if(s!==6)r=s===7&&A.aQ(a.x)
return r},
ar(a){var s=a.w
return s===2||s===3||s===4||s===5||a===t.X},
h7(a,b){var s,r,q=Object.keys(b),p=q.length
for(s=0;s<p;++s){r=q[s]
a[r]=b[r]}},
eB(a){return a>0?new Array(a):v.typeUniverse.sEA},
J:function J(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
cz:function cz(){this.c=this.b=this.a=null},
ez:function ez(a){this.a=a},
cy:function cy(){},
br:function br(a){this.a=a},
iv(){var s,r,q
if(self.scheduleImmediate!=null)return A.jK()
if(self.MutationObserver!=null&&self.document!=null){s={}
r=self.document.createElement("div")
q=self.document.createElement("span")
s.a=null
new self.MutationObserver(A.cF(new A.ed(s),1)).observe(r,{childList:true})
return new A.ec(s,r,q)}else if(self.setImmediate!=null)return A.jL()
return A.jM()},
iw(a){self.scheduleImmediate(A.cF(new A.ee(a),0))},
ix(a){self.setImmediate(A.cF(new A.ef(a),0))},
iy(a){A.fh(B.x,a)},
fh(a,b){return A.iI(a.a/1000|0,b)},
fS(a,b){return A.iJ(a.a/1000|0,b)},
iI(a,b){var s=new A.bq()
s.aV(a,b)
return s},
iJ(a,b){var s=new A.bq()
s.aW(a,b)
return s},
f6(a){var s
if(t.Q.b(a)){s=a.gN()
if(s!=null)return s}return B.w},
fJ(a,b,c){var s=new A.K($.w,c.j("K<0>"))
A.it(a,new A.d5(b,s,c))
return s},
jf(a,b){if($.w===B.c)return null
return null},
fi(a,b,c){var s,r,q,p={},o=p.a=a
while(s=o.a,(s&4)!==0){o=o.c
p.a=o}if(o===b){s=A.ff()
b.b_(new A.P(new A.O(!0,o,null,"Cannot complete a future with itself"),s))
return}r=b.a&1
s=o.a=s|r
if((s&24)===0){q=b.c
b.a=b.a&1|4
b.c=o
o.ar(q)
return}if(!c)if(b.c==null)o=(s&16)===0||r!==0
else o=!1
else o=!0
if(o){q=b.T()
b.R(p.a)
A.aJ(b,q)
return}b.a^=2
A.eR(null,null,b.b,new A.ej(p,b))},
aJ(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g={},f=g.a=a
for(;;){s={}
r=f.a
q=(r&16)===0
p=!q
if(b==null){if(p&&(r&1)===0){f=f.c
A.eP(f.a,f.b)}return}s.a=b
o=b.a
for(f=b;o!=null;f=o,o=n){f.a=null
A.aJ(g.a,f)
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
if(r){A.eP(m.a,m.b)
return}j=$.w
if(j!==k)$.w=k
else j=null
f=f.c
if((f&15)===8)new A.en(s,g,p).$0()
else if(q){if((f&1)!==0)new A.em(s,m).$0()}else if((f&2)!==0)new A.el(g,s).$0()
if(j!=null)$.w=j
f=s.c
if(f instanceof A.K){r=s.a.$ti
r=r.j("aX<2>").b(f)||!r.y[1].b(f)}else r=!1
if(r){i=s.a.b
if((f.a&24)!==0){h=i.c
i.c=null
b=i.U(h)
i.a=f.a&30|i.a&1
i.c=f.c
g.a=f
continue}else A.fi(f,i,!0)
return}}i=s.a.b
h=i.c
i.c=null
b=i.U(h)
f=s.b
r=s.c
if(!f){i.a=8
i.c=r}else{i.a=i.a&1|16
i.c=r}g.a=i
f=i}},
jy(a,b){if(t.C.b(a))return b.bu(a)
if(t.v.b(a))return a
throw A.h(A.fB(a,"onError",u.c))},
jw(){var s,r
for(s=$.aN;s!=null;s=$.aN){$.bz=null
r=s.b
$.aN=r
if(r==null)$.bx=null
s.a.$0()}},
jD(){$.fp=!0
try{A.jw()}finally{$.bz=null
$.fp=!1
if($.aN!=null)$.fz().$1(A.hs())}},
hq(a){var s=new A.cx(a),r=$.bx
if(r==null){$.aN=$.bx=s
if(!$.fp)$.fz().$1(A.hs())}else $.bx=r.b=s},
jA(a){var s,r,q,p=$.aN
if(p==null){A.hq(a)
$.bz=$.bx
return}s=new A.cx(a)
r=$.bz
if(r==null){s.b=p
$.aN=$.bz=s}else{q=r.b
s.b=q
$.bz=r.b=s
if(q==null)$.bx=s}},
it(a,b){var s=$.w
if(s===B.c)return A.fh(a,b)
return A.fh(a,s.aA(b))},
iu(a,b){var s=$.w
if(s===B.c)return A.fS(a,b)
return A.fS(a,s.bi(b,t.ae))},
eP(a,b){A.jA(new A.eQ(a,b))},
hn(a,b,c,d){var s,r=$.w
if(r===c)return d.$0()
$.w=c
s=r
try{r=d.$0()
return r}finally{$.w=s}},
ho(a,b,c,d,e){var s,r=$.w
if(r===c)return d.$1(e)
$.w=c
s=r
try{r=d.$1(e)
return r}finally{$.w=s}},
jz(a,b,c,d,e,f){var s,r=$.w
if(r===c)return d.$2(e,f)
$.w=c
s=r
try{r=d.$2(e,f)
return r}finally{$.w=s}},
eR(a,b,c,d){if(B.c!==c){d=c.aA(d)
d=d}A.hq(d)},
ed:function ed(a){this.a=a},
ec:function ec(a,b,c){this.a=a
this.b=b
this.c=c},
ee:function ee(a){this.a=a},
ef:function ef(a){this.a=a},
bq:function bq(){this.c=0},
ey:function ey(a,b){this.a=a
this.b=b},
ex:function ex(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
P:function P(a,b){this.a=a
this.b=b},
d5:function d5(a,b,c){this.a=a
this.b=b
this.c=c},
cA:function cA(a,b,c,d,e){var _=this
_.a=null
_.b=a
_.c=b
_.d=c
_.e=d
_.$ti=e},
K:function K(a,b){var _=this
_.a=0
_.b=a
_.c=null
_.$ti=b},
eh:function eh(a,b){this.a=a
this.b=b},
ek:function ek(a,b){this.a=a
this.b=b},
ej:function ej(a,b){this.a=a
this.b=b},
ei:function ei(a,b){this.a=a
this.b=b},
en:function en(a,b,c){this.a=a
this.b=b
this.c=c},
eo:function eo(a,b){this.a=a
this.b=b},
ep:function ep(a){this.a=a},
em:function em(a,b){this.a=a
this.b=b},
el:function el(a,b){this.a=a
this.b=b},
cx:function cx(a){this.a=a
this.b=null},
eC:function eC(){},
eu:function eu(){},
ev:function ev(a,b){this.a=a
this.b=b},
ew:function ew(a,b,c){this.a=a
this.b=b
this.c=c},
eQ:function eQ(a,b){this.a=a
this.b=b},
fW(a,b){var s=a[b]
return s===a?null:s},
fX(a,b,c){if(c==null)a[b]=a
else a[b]=c},
iz(){var s=Object.create(null)
A.fX(s,"<non-identifier-key>",s)
delete s["<non-identifier-key>"]
return s},
q(a,b,c){return A.jR(a,new A.af(b.j("@<0>").u(c).j("af<1,2>")))},
dJ(a,b){return new A.af(a.j("@<0>").u(b).j("af<1,2>"))},
aB(a){return new A.bh(a.j("bh<0>"))},
fj(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s},
fY(a,b,c){var s=new A.aL(a,b,c.j("aL<0>"))
s.c=a.e
return s},
fN(a){var s,r
if(A.fv(a))return"{...}"
s=new A.cs("")
try{r={}
$.am.push(a)
s.a+="{"
r.a=!0
a.a9(0,new A.dK(r,s))
s.a+="}"}finally{$.am.pop()}r=s.a
return r.charCodeAt(0)==0?r:r},
be:function be(){},
bg:function bg(a){var _=this
_.a=0
_.e=_.d=_.c=_.b=null
_.$ti=a},
bf:function bf(a,b){this.a=a
this.$ti=b},
cB:function cB(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
bh:function bh(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
er:function er(a){this.a=a
this.c=this.b=null},
aL:function aL(a,b,c){var _=this
_.a=a
_.b=b
_.d=_.c=null
_.$ti=c},
r:function r(){},
a4:function a4(){},
dK:function dK(a,b){this.a=a
this.b=b},
aG:function aG(){},
bo:function bo(){},
jP(a){var s=A.il(a)
if(s!=null)return s
throw A.h(A.fI("Invalid double",a))},
i3(a,b){a=A.B(a,new Error())
a.stack=b.i(0)
throw a},
fM(a,b,c,d){var s,r=c?J.fK(a,d):J.i6(a,d)
if(a!==0&&b!=null)for(s=0;s<r.length;++s)r[s]=b
return r},
id(a,b,c){var s,r,q=A.b([],c.j("t<0>"))
for(s=a.length,r=0;r<a.length;a.length===s||(0,A.M)(a),++r)q.push(a[r])
q.$flags=1
return q},
c_(a,b){var s,r
if(Array.isArray(a))return A.b(a.slice(0),b.j("t<0>"))
s=A.b([],b.j("t<0>"))
for(r=J.cG(a);r.k();)s.push(r.gl())
return s},
ie(a,b,c){var s,r=J.fK(a,c)
for(s=0;s<a;++s)r[s]=b.$1(s)
return r},
io(a){return new A.dG(a,A.ia(a,!1,!0,!1,!1,""))},
fR(a,b,c){var s=J.cG(b)
if(!s.k())return a
if(c.length===0){do a+=A.o(s.gl())
while(s.k())}else{a+=A.o(s.gl())
while(s.k())a=a+c+A.o(s.gl())}return a},
ff(){return A.ap(new Error())},
d0(a){if(typeof a=="number"||A.eO(a)||a==null)return J.bC(a)
if(typeof a=="string")return JSON.stringify(a)
return A.fP(a)},
i4(a,b){A.ht(a,"error",t.K)
A.ht(b,"stackTrace",t.l)
A.i3(a,b)},
bG(a){return new A.bF(a)},
aR(a,b){return new A.O(!1,null,b,a)},
fB(a,b,c){return new A.O(!0,a,b,c)},
dS(a,b,c,d,e){return new A.cj(b,c,!0,a,d,"Invalid value")},
im(a,b,c){if(0>a||a>c)throw A.h(A.dS(a,0,c,"start",null))
if(b!=null){if(a>b||b>c)throw A.h(A.dS(b,a,c,"end",null))
return b}return c},
eb(a){return new A.bd(a)},
fU(a){return new A.cu(a)},
is(a){return new A.cq(a)},
Q(a){return new A.bJ(a)},
fH(a){return new A.eg(a)},
fI(a,b){return new A.d4(a,b)},
i5(a,b,c){var s,r
if(A.fv(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}s=A.b([],t.s)
$.am.push(a)
try{A.js(a,s)}finally{$.am.pop()}r=A.fR(b,s,", ")+c
return r.charCodeAt(0)==0?r:r},
fb(a,b,c){var s,r
if(A.fv(a))return b+"..."+c
s=new A.cs(b)
$.am.push(a)
try{r=s
r.a=A.fR(r.a,a,", ")}finally{$.am.pop()}s.a+=c
r=s.a
return r.charCodeAt(0)==0?r:r},
js(a,b){var s,r,q,p,o,n,m,l=a.gq(a),k=0,j=0
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
ih(a,b,c,d){var s
if(B.l===c){s=B.b.gm(a)
b=J.N(b)
return A.fg(A.a5(A.a5($.f5(),s),b))}if(B.l===d){s=B.b.gm(a)
b=J.N(b)
c=J.N(c)
return A.fg(A.a5(A.a5(A.a5($.f5(),s),b),c))}s=B.b.gm(a)
b=J.N(b)
c=J.N(c)
d=J.N(d)
d=A.fg(A.a5(A.a5(A.a5(A.a5($.f5(),s),b),c),d))
return d},
hB(a){A.k1(a)},
ax:function ax(a){this.a=a},
p:function p(){},
bF:function bF(a){this.a=a},
U:function U(){},
O:function O(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
cj:function cj(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.a=c
_.b=d
_.c=e
_.d=f},
bd:function bd(a){this.a=a},
cu:function cu(a){this.a=a},
cq:function cq(a){this.a=a},
bJ:function bJ(a){this.a=a},
cd:function cd(){},
bb:function bb(){},
eg:function eg(a){this.a=a},
d4:function d4(a,b){this.a=a
this.b=b},
e:function e(){},
ai:function ai(a,b,c){this.a=a
this.b=b
this.$ti=c},
A:function A(){},
j:function j(){},
cD:function cD(){},
e_:function e_(){this.b=this.a=0},
cs:function cs(a){this.a=a},
bw(a){var s
if(typeof a=="function")throw A.h(A.aR("Attempting to rewrap a JS function.",null))
s=function(b,c){return function(d){return b(c,d,arguments.length)}}(A.j6,a)
s[$.fx()]=a
return s},
j6(a,b,c){if(c>=1)return a.$1(b)
return a.$0()},
hl(a){return a==null||A.eO(a)||typeof a=="number"||typeof a=="string"||t.U.b(a)||t.bX.b(a)||t.ca.b(a)||t.e.b(a)||t.c0.b(a)||t.k.b(a)||t.bk.b(a)||t.B.b(a)||t.q.b(a)||t.J.b(a)||t.Y.b(a)},
bB(a){if(A.hl(a))return a
return new A.f_(new A.bg(t.A)).$1(a)},
f_:function f_(a){this.a=a},
at:function at(a){this.b=a},
hj(a,b){var s=b.a
if(s===0)return null
return b},
a9(a,b,c,d,e,f,g){var s=!1
if(c==null)s=d==null
if(s)return null
s=A.dJ(t.N,t.co)
if(c!=null)s.t(0,"click",c)
if(d!=null)s.t(0,"input",d)
return s},
d(a,b,c){var s=null
return new A.a_("div",s,b,c,s,A.a9(s,s,s,s,s,s,s),a)},
a(a,b){var s=null
return new A.aH("span",b,a,s,s,A.a9(s,s,s,s,s,s,s),B.a)},
aj(a,b){var s=null
return new A.ce("p",b,a,s,s,A.a9(s,s,s,s,s,s,s),B.a)},
d6(a,b){var s=null
return new A.bP("h2",b,a,s,s,A.a9(s,s,s,s,s,s,s),B.a)},
f9(a,b){var s=null
return new A.az("h3",b,a,s,s,A.a9(s,s,s,s,s,s,s),B.a)},
E(a,b,c,d){var s=null
return new A.av("button",d,b,s,s,A.a9(s,s,c,s,s,s,s),a)},
fa(a,b,c,d){var s=null,r=t.N
r=A.dJ(r,r)
r.t(0,"placeholder",c)
if(d!=null)r.t(0,"type",d)
return new A.bR("input",s,a,s,A.hj(s,r),A.a9(s,s,s,b,s,s,s),B.a)},
as(a,b,c,d){var s=null,r=t.N
r=A.dJ(r,r)
r.t(0,"href",c)
return new A.bD("a",d,b,s,A.hj(s,r),A.a9(s,s,s,s,s,s,s),a)},
cn(a,b,c){return new A.cm("section",null,c,null,a,null,b)},
dO(a,b){var s=null
return new A.cg("pre",s,b,s,s,s,a)},
m:function m(){},
aT:function aT(){},
aW:function aW(){},
c0:function c0(){},
aV:function aV(){},
ck:function ck(){},
bN:function bN(a){this.a=a},
x:function x(a){this.a=a},
a0:function a0(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.$ti=d},
y:function y(a){this.a=a},
a_:function a_(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
aH:function aH(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
ce:function ce(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
bO:function bO(a,b,c,d,e,f,g){var _=this
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
az:function az(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
av:function av(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
bR:function bR(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
bD:function bD(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
bQ:function bQ(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
bM:function bM(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
c1:function c1(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
cc:function cc(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
cm:function cm(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
cg:function cg(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
k0(a,b){var s,r,q=A.aB(t.M),p=A.bA(a,new A.bn(q))
for(s=p.length,r=0;r<p.length;p.length===s||(0,A.M)(p),++r)b.appendChild(p[r])
A.c_(q,q.$ti.c)
return new A.cU()},
bA(a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3=null,a4=a6 instanceof A.y,a5=a4?a6.a:a3
if(a4){s=v.G.document.createElement("span")
s.innerHTML=a5
return A.b([s],t.O)}r=a6 instanceof A.aT
q=a3
p=a3
o=a3
n=a3
m=a3
l=a3
k=a3
if(r){j=a6.a
i=a6.b
o=a6.c
n=a6.d
m=a6.e
l=a6.f
q=a6.r
k=q
p=i}else j=a3
if(r){a4=v.G
h=a4.document.createElement(j)
if(o!=null)h.className=o
if(n!=null)h.setAttribute("style",n)
if(m!=null)for(g=new A.ag(m,A.a8(m).j("ag<1,2>")).gq(0);g.k();){f=g.d
h.setAttribute(f.a,f.b)}if(l!=null)for(g=new A.ag(l,A.a8(l).j("ag<1,2>")).gq(0);g.k();){e=g.d
A.j3(h,e.a,e.b)}if(p!=null)h.appendChild(a4.document.createTextNode(p))
for(a4=k.length,d=0;d<k.length;k.length===a4||(0,A.M)(k),++d){c=A.bA(k[d],a7)
for(g=c.length,b=0;b<c.length;c.length===g||(0,A.M)(c),++b)h.appendChild(c[b])}return A.b([h],t.O)}a=a6 instanceof A.aW
if(a)k=a6.a
else k=a3
if(a){a0=A.b([],t.O)
for(a4=k.length,d=0;d<k.length;k.length===a4||(0,A.M)(k),++d)B.h.az(a0,A.bA(k[d],a7))
return a0}a4=a6 instanceof A.x
a1=a4?a6.a:a3
if(a4){a2=v.G.document.createElement("span")
a2.setAttribute("data-bloom-live","")
A.j5(a2,a7,a1,a3)
return A.b([a2],t.O)}if(a6 instanceof A.a0){a2=v.G.document.createElement("span")
a2.setAttribute("data-bloom-foreach","")
A.j4(a2,a7,a6)
return A.b([a2],t.O)}},
j4(a,b,c){var s=A.dJ(t.N,t.cl)
b.a.a6(0,new A.eF(A.hv(new A.eG(new A.eH(c,c.c,s,a))),s))},
j5(a,b,c,d){var s=new A.bn(A.aB(t.M))
b.a.a6(0,new A.eJ(A.hv(new A.eK(new A.eL(s,c,d,a))),s))},
j3(a,b,c){a.addEventListener(b,A.bw(new A.eD(b,c)))},
jI(a,b){var s,r,q,p=null,o=null
try{s=b.target
if(s!=null){r=s
p=A.ju(r,"value")
o=A.jt(r,"checked")}}catch(q){}return new A.at(p)},
ju(a,b){var s,r,q
try{s=v.G.Reflect.get(a,b)
if(s==null)return null
if(s!=null&&typeof s==="string"){r=A.hb(s)
return r}return null}catch(q){return null}},
jt(a,b){var s,r,q
try{s=v.G.Reflect.get(a,b)
if(s==null)return null
if(s!=null&&typeof s==="boolean"){r=A.ha(s)
return r}return null}catch(q){return null}},
cU:function cU(){},
bn:function bn(a){this.a=a},
aK:function aK(a,b){this.b=a
this.c=b},
eH:function eH(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
eI:function eI(a){this.a=a},
eG:function eG(a){this.a=a},
eF:function eF(a,b){this.a=a
this.b=b},
eL:function eL(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
eK:function eK(a){this.a=a},
eJ:function eJ(a,b){this.a=a
this.b=b},
eD:function eD(a,b){this.a=a
this.b=b},
cH:function cH(a){this.a=a},
cK:function cK(a){this.a=a},
cI:function cI(a){this.a=a},
cJ:function cJ(a){this.a=a},
cM:function cM(a){this.a=a},
cN:function cN(a){this.a=a},
cO:function cO(a){this.a=a},
cP:function cP(a){this.a=a},
cQ:function cQ(a){this.a=a},
cR:function cR(a){this.a=a},
cS:function cS(a){this.a=a},
cT:function cT(){},
cL:function cL(){},
cV:function cV(a){this.a=a},
cY:function cY(a){this.a=a},
cZ:function cZ(a){this.a=a},
cX:function cX(a,b,c){this.a=a
this.b=b
this.c=c},
cW:function cW(a,b){this.a=a
this.b=b},
d1:function d1(){},
d7:function d7(a){this.a=a},
d9:function d9(a){this.a=a},
d8:function d8(a){this.a=a},
dd:function dd(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=""
_.e=d
_.f=$
_.r=e
_.w=f
_.y=_.x=$},
dD:function dD(a){this.a=a},
dC:function dC(a){this.a=a},
dE:function dE(a){this.a=a},
dB:function dB(a){this.a=a},
dr:function dr(a,b,c){this.a=a
this.b=b
this.c=c},
dq:function dq(a,b){this.a=a
this.b=b},
dw:function dw(a){this.a=a},
dx:function dx(a){this.a=a},
dy:function dy(a){this.a=a},
dz:function dz(a){this.a=a},
du:function du(a,b){this.a=a
this.b=b},
dt:function dt(a){this.a=a},
dv:function dv(a,b){this.a=a
this.b=b},
ds:function ds(a){this.a=a},
dA:function dA(){},
dg:function dg(a){this.a=a},
dh:function dh(a){this.a=a},
di:function di(a){this.a=a},
dj:function dj(a){this.a=a},
dk:function dk(a){this.a=a},
dl:function dl(a){this.a=a},
dm:function dm(a){this.a=a},
dn:function dn(a){this.a=a},
dp:function dp(a){this.a=a},
de:function de(){},
df:function df(){},
dL:function dL(a){this.a=a},
dM:function dM(a){this.a=a},
jZ(){var s,r=null,q="hover:text-white transition-colors",p=$.hG(),o=t.S,n=t.N,m=new A.d1(),l=t.t,k=A.d(A.b([new A.dL(p).A(),new A.c1("main",r,"flex-1 flex flex-col",r,r,r,A.b([new A.d7(p).A(),new A.cH(p).A(),new A.dd(p,A.H(0,o),A.H(A.b([new A.a6(!0,"1","Build fine-grained Web app in Dart"),new A.a6(!0,"2","Vendor NPM packages with Bun"),new A.a6(!1,"3","Deploy to Cloudflare edge in <1ms")],t.h),t.E),A.H(42,o),A.H("",n),A.H("",n)).A(),A.cn(A.q(["id","features"],n,n),A.b([A.d(A.b([A.a(u.a,"Core Architecture"),A.d6(u.d,"Engineered for Zero Overhead"),A.aj("text-zinc-400 text-base leading-relaxed","A web-first framework written in Dart that compiles pure AST descriptors directly to the DOM and server SSR without canvas or virtual DOM bloat.")],l),"text-center max-w-3xl mx-auto mb-16",r),A.d(A.b([m.P("The exact same Dart AST descriptors execute in <1ms on server isolates to output SEO-optimized static HTML, then seamlessly activate fine-grained signal subscriptions in the browser.",'<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>',"Sub-Millisecond","Dual-Backend SSR & Instant Hydration"),m.P("ForEachNode uses active key registries to reuse existing DOM elements on list updates, preserving input focus, scroll positions, and native CSS transitions during high-throughput mutations.",'<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16"/>',"Zero DOM Tear-down","Keyed DOM List Reconciliation"),m.P("Consume any of the 2.5M+ NPM packages surgically. The Bloom CLI runs Bun to extract ESM bundles into web/vendor/ and manages browser import maps automatically with CDN fallback.",'<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>',"NPM Native","Bun ESM Toolchain Orchestration"),m.P("Organize pages naturally in lib/routes/ with automatic parameter parsing ([slug].dart), nested layout cascades (_layout.dart), and dedicated 404 boundaries (_error.dart).",'<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6 3V7m6 10l4.553 2.276A1 1 0 0021 18.382V7.618a1 1 0 00-.553-.894L15 4m0 13V4m0 0L9 7"/>',"Standardized DX","Next.js File-Based Page Routing")],l),"grid grid-cols-1 md:grid-cols-2 gap-6",r)],l),"py-20 px-6 max-w-7xl mx-auto"),new A.cV(p).A()],l)),new A.bM("footer",r,"w-full border-t border-[#1E1E24] bg-[#060608] py-12 px-6",r,r,r,A.b([A.d(A.b([A.d(A.b([A.a("font-semibold text-zinc-300 font-mono","Bloom JS Native"),A.a("text-zinc-600","\u2022"),A.a(r,"MIT Open Source Framework")],l),"flex items-center gap-4",r),A.d(A.b([A.a("w-2 h-2 rounded-full bg-emerald-500 animate-pulse",r),A.a(r,"Runtime Status: Nominal (<1ms SSR)")],l),"inline-flex items-center gap-2 px-3 py-1 rounded-full bg-[#101014] border border-[#1E1E24] text-xs font-mono text-emerald-400",r),A.d(A.b([A.as(B.a,q,"https://github.com/Chidi09/Bloom","GitHub"),A.as(B.a,q,"https://github.com/Chidi09/Bloom/tree/main/packages/bloom_js_native","Docs")],l),"flex items-center gap-6",r)],l),"max-w-7xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-6 text-sm text-zinc-500",r)],l)),new A.x(new A.f0(p))],l),"min-h-screen bg-[#09090B] text-zinc-100 flex flex-col justify-between selection:bg-indigo-600 selection:text-white relative",r)
l=v.G
s=l.document.querySelector("#app")
if(s==null)A.f4(A.is('Bloom mount: selector "#app" matched no element.'))
A.k0(k,s)
l.window.requestAnimationFrame(A.bw(new A.f1()))},
f0:function f0(a){this.a=a},
f1:function f1(){},
e0:function e0(a){var _=this
_.a=a
_.b=!1
_.d=_.c=0},
e2:function e2(a){this.a=a},
e1:function e1(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
e3:function e3(a,b,c){this.a=a
this.b=b
this.c=c},
iq(){var s,r,q,p,o=A.H("main.dart",t.N),n=t.S,m=A.H(36,n),l=A.H(60,n),k=A.H(0.08,t.i)
n=A.H(1080,n)
s=J.dF(36,t.W)
for(r=0;r<36;r=q){q=r+1
s[r]=new A.C(q,(r*37+100)%999,B.b.L(r*17,100))}p=t.y
p=new A.dU(o,m,l,k,n,A.H(s,t.w),A.H(!0,p),A.H(null,t.u),A.H(!1,p))
p.bf()
return p},
C:function C(a,b,c){this.a=a
this.b=b
this.c=c},
dU:function dU(a,b,c,d,e,f,g,h,i){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h
_.x=i
_.z=0},
dY:function dY(a){this.a=a},
dX:function dX(a,b){this.a=a
this.b=b},
dW:function dW(a){this.a=a},
dV:function dV(a){this.a=a},
fn(){var s,r,q,p,o,n,m=$.X
if(m>1){$.X=m-1
return}s=null
r=!1
while(m=$.eE,m!=null){q=m
$.eE=null
$.eM=$.eM+1
while(q!=null){o=q.f
q.f=null
q.r&=4294967293
if((q.r&8)===0&&A.hk(q))try{q.ag()}catch(n){p=A.ac(n)
if(!r){s=p
r=!0}}q=o}}$.eM=0
$.X=$.X-1
if(r)throw A.h(s)},
fs(a,b){var s=$.eN,r=$.by+1
$.by=r
return new A.aS(a,s-1,!1,null,r,A.aB(t.M),b.j("aS<0>"))},
hv(a){var s,r=$.by+1
$.by=r
s=new A.bK(a,null,r,A.aB(t.M))
s.aU(a,null)
return s.gbk()},
ir(a,b,c,d){var s=$.by+1
$.by=s
s=new A.ba(a,new A.dZ(d),!1,c,s,A.aB(t.M),d.j("ba<0>"))
s.z=a
return s},
H(a,b){return A.ir(a,!1,null,b)},
h8(a){var s,r,q,p=null,o=$.D
if(o==null)return p
s=a.f
if(s==null||s.d!==o){o=o.gp()
r=$.D
s=new A.es(a,o,p,r,p,p,0,s)
if(r.gp()!=null)$.D.gp().c=s
$.D.sp(s)
a.f=s
if(($.D.gal()&32)!==0)a.W(s)
return s}else if(s.r===-1){s.r=0
r=s.c
if(r!=null){r.b=s.b
q=s.b
if(q!=null)q.c=r
s.b=o.gp()
s.c=null
$.D.gp().c=s
$.D.sp(s)}return s}return p},
hk(a){var s,r
for(s=a.gp();s!=null;s=s.c){r=s.a
if(r.e!==s.r||!r.a4()||r.e!==s.r)return!0}return!1},
hm(a){var s,r,q,p
for(s=a.gp();s!=null;s=p){r=s.a
q=r.f
if(q!=null)s.w=q
r.f=s
s.r=-1
p=s.c
if(p==null){a.sp(s)
break}}},
hd(a){var s,r,q,p,o=a.gp()
for(s=null;o!=null;o=r){r=o.b
if(o.r===-1){o.a.G(o)
if(r!=null)r.c=o.c
q=o.c
if(q!=null)q.b=r}else s=o
q=o.a
p=o.w
q.f=p
if(p!=null)o.w=null}a.sp(s)},
hc(a){var s,r,q=a.d
a.d=null
if(q!=null){$.X=$.X+1
s=$.D
$.D=null
try{q.$0()}catch(r){a.r=(a.r&=4294967294)|8
A.fm(a)
throw r}finally{$.D=s
A.fn()}}},
fm(a){var s
for(s=a.e;s!=null;s=s.c)s.a.G(s)
a.e=a.a=null
A.hc(a)},
aS:function aS(a,b,c,d,e,f,g){var _=this
_.y=$
_.z=a
_.Q=null
_.as=b
_.at=4
_.ax=null
_.a=c
_.b=!1
_.c=d
_.d=e
_.e=0
_.r=_.f=null
_.w=f
_.$ti=g},
bK:function bK(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.f=_.e=_.d=null
_.r=32
_.w=d
_.x=!1},
d_:function d_(a,b){this.a=a
this.b=b},
aF:function aF(){},
ba:function ba(a,b,c,d,e,f,g){var _=this
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
dZ:function dZ(a){this.a=a},
es:function es(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
co:function co(){},
cp:function cp(a){this.a=a},
ay:function ay(){},
hD(a){return v.mangledGlobalNames[a]},
k1(a){if(typeof dartPrint=="function"){dartPrint(a)
return}if(typeof console=="object"&&typeof console.log!="undefined"){console.log(a)
return}if(typeof print=="function"){print(a)
return}throw"Unable to print message: "+String(a)},
k3(a){throw A.B(A.ib(a),new Error())},
ab(){throw A.B(A.ic(""),new Error())},
hY(a){var s,r,q,p,o,n,m="rgba(255, 255, 255, 0.05)"
try{r=t.n
q=t.N
p=t.K
o=t.G
s=A.aM(A.bB(A.q(["type","bar","data",A.q(["labels",A.b(["Bloom JS Native","Next.js (React 19)","Nuxt 3 (Vue 3)","Angular SSR","SvelteKit"],t.s),"datasets",A.b([A.q(["label","SSR Response Time (ms) \u2014 Lower is better","data",A.b([0.4,18.2,14.5,26,6.8],r),"backgroundColor","rgba(99, 102, 241, 0.85)","borderColor","rgba(99, 102, 241, 1)","borderWidth",1,"borderRadius",6],q,p),A.q(["label","Client Bundle Baseline (kB gzip) \u2014 Lower is better","data",A.b([20.1,98.4,62,145,28.5],r),"backgroundColor","rgba(139, 92, 246, 0.75)","borderColor","rgba(139, 92, 246, 1)","borderWidth",1,"borderRadius",6],q,p)],t.x)],q,t.D),"options",A.q(["responsive",!0,"maintainAspectRatio",!1,"plugins",A.q(["legend",A.q(["labels",A.q(["color","#A1A1AA","font",A.q(["family","JetBrains Mono","size",11],q,p)],q,p)],q,o),"tooltip",A.q(["backgroundColor","#14141A","titleColor","#FFFFFF","bodyColor","#A1A1AA","borderColor","#27272A","borderWidth",1],q,p)],q,o),"scales",A.q(["x",A.q(["grid",A.q(["color",m],q,q),"ticks",A.q(["color","#A1A1AA","font",A.q(["family","Plus Jakarta Sans","size",12,"weight","600"],q,p)],q,p)],q,o),"y",A.q(["grid",A.q(["color",m],q,q),"ticks",A.q(["color","#71717A","font",A.q(["family","JetBrains Mono","size",11],q,p)],q,p)],q,o)],q,t.cy)],q,p)],q,t.z)))
new v.G.Chart(a,s)}catch(n){}},
aw(a,b){var s,r,q
try{r=t.N
s=A.aM(A.bB(A.q(["particleCount",60,"spread",70,"origin",A.q(["x",a,"y",b],r,t.i),"colors",A.b(["#6366F1","#8B5CF6","#3B82F6","#10B981"],t.s),"disableForReducedMotion",!0],r,t.z)))
v.G.confetti(s)}catch(q){}}},B={}
var w=[A,J,B]
var $={}
A.fc.prototype={}
J.bS.prototype={
D(a,b){return a===b},
gm(a){return A.ch(a)},
i(a){return"Instance of '"+A.ci(a)+"'"},
gn(a){return A.an(A.fo(this))}}
J.bU.prototype={
i(a){return String(a)},
gm(a){return a?519018:218159},
gn(a){return A.an(t.y)},
$in:1,
$iv:1}
J.aZ.prototype={
D(a,b){return null==b},
i(a){return"null"},
gm(a){return 0},
$in:1,
$iA:1}
J.b1.prototype={$iu:1}
J.a2.prototype={
gm(a){return 0},
i(a){return String(a)}}
J.cf.prototype={}
J.bc.prototype={}
J.a1.prototype={
i(a){var s=a[$.hF()]
if(s==null)s=a[$.fx()]
if(s==null)return this.aR(a)
return"JavaScript function for "+J.bC(s)},
$iae:1}
J.b0.prototype={
gm(a){return 0},
i(a){return String(a)}}
J.b2.prototype={
gm(a){return 0},
i(a){return String(a)}}
J.t.prototype={
aM(a,b){return new A.W(a,b,A.cE(a).j("W<1>"))},
az(a,b){var s
a.$flags&1&&A.k4(a,"addAll",2)
if(Array.isArray(b)){this.aZ(a,b)
return}for(s=J.cG(b);s.k();)a.push(s.gl())},
aZ(a,b){var s,r=b.length
if(r===0)return
if(a===b)throw A.h(A.Q(a))
for(s=0;s<r;++s)a.push(b[s])},
H(a,b,c){return new A.T(a,b,A.cE(a).j("@<1>").u(c).j("T<1,2>"))},
bs(a,b){var s,r=A.fM(a.length,"",!1,t.N)
for(s=0;s<a.length;++s)r[s]=A.o(a[s])
return r.join(b)},
X(a,b){return a[b]},
i(a){return A.fb(a,"[","]")},
gq(a){return new J.bE(a,a.length,A.cE(a).j("bE<1>"))},
gm(a){return A.ch(a)},
gB(a){return a.length},
$ii:1,
$ie:1,
$ik:1}
J.bT.prototype={
bH(a){var s,r,q
if(!Array.isArray(a))return null
s=a.$flags|0
if((s&4)!==0)r="const, "
else if((s&2)!==0)r="unmodifiable, "
else r=(s&1)!==0?"fixed, ":""
q="Instance of '"+A.ci(a)+"'"
if(r==="")return q
return q+" ("+r+"length: "+a.length+")"}}
J.dH.prototype={}
J.bE.prototype={
gl(){var s=this.d
return s==null?this.$ti.c.a(s):s},
k(){var s,r=this,q=r.a,p=q.length
if(r.b!==p)throw A.h(A.M(q))
s=r.c
if(s>=p){r.d=null
return!1}r.d=q[s]
r.c=s+1
return!0}}
J.b_.prototype={
a7(a,b){var s
if(a<b)return-1
else if(a>b)return 1
else if(a===b){if(a===0){s=B.b.gY(b)
if(this.gY(a)===s)return 0
if(this.gY(a))return-1
return 1}return 0}else if(isNaN(a)){if(isNaN(b))return 0
return 1}else return-1},
gY(a){return a===0?1/a<0:a<0},
bm(a){var s,r
if(a>=0){if(a<=2147483647)return a|0}else if(a>=-2147483648){s=a|0
return a===s?s:s-1}r=Math.floor(a)
if(isFinite(r))return r
throw A.h(A.eb(""+a+".floor()"))},
aB(a,b,c){if(B.b.a7(b,c)>0)throw A.h(A.jJ(b))
if(this.a7(a,b)<0)return b
if(this.a7(a,c)>0)return c
return a},
bG(a,b){var s
if(b>20)throw A.h(A.dS(b,0,20,"fractionDigits",null))
s=a.toFixed(b)
if(a===0&&this.gY(a))return"-"+s
return s},
i(a){if(a===0&&1/a<0)return"-0.0"
else return""+a},
gm(a){var s,r,q,p,o=a|0
if(a===o)return o&536870911
s=Math.abs(a)
r=Math.log(s)/0.6931471805599453|0
q=Math.pow(2,r)
p=s<1?s/q:q/s
return((p*9007199254740992|0)+(p*3542243181176521|0))*599197+r*1259&536870911},
O(a,b){return a-b},
L(a,b){var s=a%b
if(s===0)return 0
if(s>0)return s
return s+b},
aT(a,b){if((a|0)===a)if(b>=1)return a/b|0
return this.av(a,b)},
au(a,b){return(a|0)===a?a/b|0:this.av(a,b)},
av(a,b){var s=a/b
if(s>=-2147483648&&s<=2147483647)return s|0
if(s>0){if(s!==1/0)return Math.floor(s)}else if(s>-1/0)return Math.ceil(s)
throw A.h(A.eb("Result of truncating division is "+A.o(s)+": "+A.o(a)+" ~/ "+b))},
bd(a,b){var s
if(a>0)s=this.bc(a,b)
else{s=b>31?31:b
s=a>>s>>>0}return s},
bc(a,b){return b>31?0:a>>>b},
gn(a){return A.an(t.H)},
$il:1}
J.aY.prototype={
gn(a){return A.an(t.S)},
$in:1,
$ic:1}
J.bV.prototype={
gn(a){return A.an(t.i)},
$in:1}
J.aA.prototype={
aQ(a,b,c){return a.substring(b,A.im(b,c,a.length))},
aK(a){var s,r,q,p=a.trim(),o=p.length
if(o===0)return p
if(p.charCodeAt(0)===133){s=J.i8(p,1)
if(s===o)return""}else s=0
r=o-1
q=p.charCodeAt(r)===133?J.i9(p,r):o
if(s===0&&q===o)return p
return p.substring(s,q)},
aO(a,b){var s,r
if(0>=b)return""
if(b===1||a.length===0)return a
if(b!==b>>>0)throw A.h(B.v)
for(s=a,r="";;){if((b&1)===1)r=s+r
b=b>>>1
if(b===0)break
s+=s}return r},
aI(a,b,c){var s=b-a.length
if(s<=0)return a
return this.aO(c,s)+a},
i(a){return a},
gm(a){var s,r,q
for(s=a.length,r=0,q=0;q<s;++q){r=r+a.charCodeAt(q)&536870911
r=r+((r&524287)<<10)&536870911
r^=r>>6}r=r+((r&67108863)<<3)&536870911
r^=r>>11
return r+((r&16383)<<15)&536870911},
gn(a){return A.an(t.N)},
$in:1,
$if:1}
A.b3.prototype={
i(a){return"LateInitializationError: "+this.a}}
A.dT.prototype={}
A.i.prototype={}
A.R.prototype={
gq(a){return new A.aC(this,this.gB(0),this.$ti.j("aC<R.E>"))},
H(a,b,c){return new A.T(this,b,this.$ti.j("@<R.E>").u(c).j("T<1,2>"))}}
A.aC.prototype={
gl(){var s=this.d
return s==null?this.$ti.c.a(s):s},
k(){var s,r=this,q=r.a,p=J.hw(q),o=p.gB(q)
if(r.b!==o)throw A.h(A.Q(q))
s=r.c
if(s>=o){r.d=null
return!1}r.d=p.X(q,s);++r.c
return!0}}
A.S.prototype={
gq(a){var s=this.a
return new A.c2(s.gq(s),this.b,A.a8(this).j("c2<1,2>"))}}
A.ad.prototype={$ii:1}
A.c2.prototype={
k(){var s=this,r=s.b
if(r.k()){s.a=s.c.$1(r.gl())
return!0}s.a=null
return!1},
gl(){var s=this.a
return s==null?this.$ti.y[1].a(s):s}}
A.T.prototype={
gB(a){return J.hT(this.a)},
X(a,b){return this.b.$1(J.hS(this.a,b))}}
A.W.prototype={
gq(a){return new A.cw(J.cG(this.a),this.b)},
H(a,b,c){return new A.S(this,b,this.$ti.j("@<1>").u(c).j("S<1,2>"))}}
A.cw.prototype={
k(){var s,r
for(s=this.a,r=this.b;s.k();)if(r.$1(s.gl()))return!0
return!1},
gl(){return this.a.gl()}}
A.aU.prototype={}
A.a6.prototype={$r:"+done,id,text(1,2,3)",$s:1}
A.dP.prototype={
$0(){return B.e.bm(1000*this.a.now())},
$S:9}
A.b9.prototype={}
A.e5.prototype={
v(a){var s,r,q=this,p=new RegExp(q.a).exec(a)
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
A.b8.prototype={
i(a){return"Null check operator used on a null value"}}
A.bW.prototype={
i(a){var s,r=this,q="NoSuchMethodError: method not found: '",p=r.b
if(p==null)return"NoSuchMethodError: "+r.a
s=r.c
if(s==null)return q+p+"' ("+r.a+")"
return q+p+"' on '"+s+"' ("+r.a+")"}}
A.cv.prototype={
i(a){var s=this.a
return s.length===0?"Error":"Error: "+s}}
A.dN.prototype={
i(a){return"Throw of null ('"+(this.a===null?"null":"undefined")+"' from JavaScript)"}}
A.bL.prototype={}
A.bp.prototype={
i(a){var s,r=this.b
if(r!=null)return r
r=this.a
s=r!==null&&typeof r==="object"?r.stack:null
return this.b=s==null?"":s},
$iaI:1}
A.Z.prototype={
i(a){var s=this.constructor,r=s==null?null:s.name
return"Closure '"+A.hE(r==null?"unknown":r)+"'"},
$iae:1,
gbI(){return this},
$C:"$1",
$R:1,
$D:null}
A.bH.prototype={$C:"$0",$R:0}
A.bI.prototype={$C:"$2",$R:2}
A.ct.prototype={}
A.cr.prototype={
i(a){var s=this.$static_name
if(s==null)return"Closure of unknown static method"
return"Closure '"+A.hE(s)+"'"}}
A.au.prototype={
D(a,b){if(b==null)return!1
if(this===b)return!0
if(!(b instanceof A.au))return!1
return this.$_target===b.$_target&&this.a===b.a},
gm(a){return(A.f3(this.a)^A.ch(this.$_target))>>>0},
i(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.ci(this.a)+"'")}}
A.cl.prototype={
i(a){return"RuntimeError: "+this.a}}
A.af.prototype={
gaa(){return new A.ah(this,A.a8(this).j("ah<1>"))},
a8(a){var s=this.b
if(s==null)return!1
return s[a]!=null},
E(a,b){var s,r,q,p,o=null
if(typeof b=="string"){s=this.b
if(s==null)return o
r=s[b]
q=r==null?o:r.b
return q}else if(typeof b=="number"&&(b&0x3fffffff)===b){p=this.c
if(p==null)return o
r=p[b]
q=r==null?o:r.b
return q}else return this.bp(b)},
bp(a){var s,r,q=this.d
if(q==null)return null
s=this.aX(q,a)
r=this.aE(s,a)
if(r<0)return null
return s[r].b},
t(a,b,c){var s,r,q=this
if(typeof b=="string"){s=q.b
q.ad(s==null?q.b=q.a2():s,b,c)}else if(typeof b=="number"&&(b&0x3fffffff)===b){r=q.c
q.ad(r==null?q.c=q.a2():r,b,c)}else q.bq(b,c)},
bq(a,b){var s,r,q,p=this,o=p.d
if(o==null)o=p.d=p.a2()
s=p.aD(a)
r=o[s]
if(r==null)o[s]=[p.a_(a,b)]
else{q=p.aE(r,a)
if(q>=0)r[q].b=b
else r.push(p.a_(a,b))}},
bw(a,b){var s=this.b9(this.b,b)
return s},
a9(a,b){var s=this,r=s.e,q=s.r
while(r!=null){b.$2(r.a,r.b)
if(q!==s.r)throw A.h(A.Q(s))
r=r.c}},
ad(a,b,c){var s=a[b]
if(s==null)a[b]=this.a_(b,c)
else s.b=c},
b9(a,b){var s
if(a==null)return null
s=a[b]
if(s==null)return null
this.bh(s)
delete a[b]
return s.b},
Z(){this.r=this.r+1&1073741823},
a_(a,b){var s,r=this,q=new A.dI(a,b)
if(r.e==null)r.e=r.f=q
else{s=r.f
s.toString
q.d=s
r.f=s.c=q}++r.a
r.Z()
return q},
bh(a){var s=this,r=a.d,q=a.c
if(r==null)s.e=q
else r.c=q
if(q==null)s.f=r
else q.d=r;--s.a
s.Z()},
aD(a){return J.N(a)&1073741823},
aX(a,b){return a[this.aD(b)]},
aE(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.Y(a[r].a,b))return r
return-1},
i(a){return A.fN(this)},
a2(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s}}
A.dI.prototype={}
A.ah.prototype={
gq(a){var s=this.a
return new A.bY(s,s.r,s.e)}}
A.bY.prototype={
gl(){return this.d},
k(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.h(A.Q(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=s.a
r.c=s.c
return!0}}}
A.bZ.prototype={
gl(){return this.d},
k(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.h(A.Q(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=s.b
r.c=s.c
return!0}}}
A.ag.prototype={
gq(a){var s=this.a
return new A.bX(s,s.r,s.e,this.$ti.j("bX<1,2>"))}}
A.bX.prototype={
gl(){var s=this.d
s.toString
return s},
k(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.h(A.Q(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=new A.ai(s.a,s.b,r.$ti.j("ai<1,2>"))
r.c=s.c
return!0}}}
A.eW.prototype={
$1(a){return this.a(a)},
$S:14}
A.eX.prototype={
$2(a,b){return this.a(a,b)},
$S:21}
A.eY.prototype={
$1(a){return this.a(a)},
$S:13}
A.bm.prototype={
i(a){return this.aw(!1)},
aw(a){var s,r,q,p,o,n=this.b6(),m=this.an(),l=(a?"Record ":"")+"("
for(s=n.length,r="",q=0;q<s;++q,r=", "){l+=r
p=n[q]
if(typeof p=="string")l=l+p+": "
o=m[q]
l=a?l+A.fP(o):l+A.o(o)}l+=")"
return l.charCodeAt(0)==0?l:l},
b6(){var s,r=this.$s
while($.et.length<=r)$.et.push(null)
s=$.et[r]
if(s==null){s=this.b1()
$.et[r]=s}return s},
b1(){var s,r,q,p=this.$r,o=p.indexOf("("),n=p.substring(1,o),m=p.substring(o),l=m==="()"?0:m.replace(/[^,]/g,"").length+1,k=t.K,j=J.dF(l,k)
for(s=0;s<l;++s)j[s]=s
if(n!==""){r=n.split(",")
s=r.length
for(q=l;s>0;){--q;--s
j[q]=r[s]}}j=A.id(j,!1,k)
j.$flags=3
return j}}
A.cC.prototype={
an(){return[this.a,this.b,this.c]},
D(a,b){var s=this
if(b==null)return!1
return b instanceof A.cC&&s.$s===b.$s&&J.Y(s.a,b.a)&&J.Y(s.b,b.b)&&J.Y(s.c,b.c)},
gm(a){var s=this
return A.ih(s.$s,s.a,s.b,s.c)}}
A.dG.prototype={
i(a){return"RegExp/"+this.a+"/"+this.b.flags}}
A.aD.prototype={
gn(a){return B.C},
$in:1,
$if7:1}
A.b6.prototype={}
A.c3.prototype={
gn(a){return B.D},
$in:1,
$if8:1}
A.aE.prototype={
gB(a){return a.length},
$iF:1}
A.b4.prototype={$ii:1,$ie:1,$ik:1}
A.b5.prototype={$ii:1,$ie:1,$ik:1}
A.c4.prototype={
gn(a){return B.E},
$in:1,
$id2:1}
A.c5.prototype={
gn(a){return B.F},
$in:1,
$id3:1}
A.c6.prototype={
gn(a){return B.G},
$in:1,
$ida:1}
A.c7.prototype={
gn(a){return B.H},
$in:1,
$idb:1}
A.c8.prototype={
gn(a){return B.I},
$in:1,
$idc:1}
A.c9.prototype={
gn(a){return B.K},
$in:1,
$ie7:1}
A.ca.prototype={
gn(a){return B.L},
$in:1,
$ie8:1}
A.b7.prototype={
gn(a){return B.M},
gB(a){return a.length},
$in:1,
$ie9:1}
A.cb.prototype={
gn(a){return B.N},
gB(a){return a.length},
$in:1,
$iea:1}
A.bi.prototype={}
A.bj.prototype={}
A.bk.prototype={}
A.bl.prototype={}
A.J.prototype={
j(a){return A.bv(v.typeUniverse,this,a)},
u(a){return A.h6(v.typeUniverse,this,a)}}
A.cz.prototype={}
A.ez.prototype={
i(a){return A.G(this.a,null)}}
A.cy.prototype={
i(a){return this.a}}
A.br.prototype={$iU:1}
A.ed.prototype={
$1(a){var s=this.a,r=s.a
s.a=null
r.$0()},
$S:8}
A.ec.prototype={
$1(a){var s,r
this.a.a=a
s=this.b
r=this.c
s.firstChild?s.removeChild(r):s.appendChild(r)},
$S:33}
A.ee.prototype={
$0(){this.a.$0()},
$S:2}
A.ef.prototype={
$0(){this.a.$0()},
$S:2}
A.bq.prototype={
aV(a,b){if(self.setTimeout!=null)self.setTimeout(A.cF(new A.ey(this,b),0),a)
else throw A.h(A.eb("`setTimeout()` not found."))},
aW(a,b){if(self.setTimeout!=null)self.setInterval(A.cF(new A.ex(this,a,Date.now(),b),0),a)
else throw A.h(A.eb("Periodic timer."))},
$ie4:1}
A.ey.prototype={
$0(){this.a.c=1
this.b.$0()},
$S:1}
A.ex.prototype={
$0(){var s,r=this,q=r.a,p=q.c+1,o=r.b
if(o>0){s=Date.now()-r.c
if(s>(p+1)*o)p=B.b.aT(s,o)}q.c=p
r.d.$1(q)},
$S:2}
A.P.prototype={
i(a){return A.o(this.a)},
$ip:1,
gN(){return this.b}}
A.d5.prototype={
$0(){var s,r,q,p,o,n,m=this,l=m.a
if(l==null){m.c.a(null)
m.b.ah(null)}else{s=null
try{s=l.$0()}catch(p){r=A.ac(p)
q=A.ap(p)
l=r
o=q
n=A.jf(l,o)
l=new A.P(l,o)
m.b.a0(l)
return}m.b.ah(s)}},
$S:1}
A.cA.prototype={
bt(a){if((this.c&15)!==6)return!0
return this.b.b.ab(this.d,a.a)},
bn(a){var s,r=this.e,q=null,p=a.a,o=this.b.b
if(t.C.b(r))q=o.bz(r,p,a.b)
else q=o.ab(r,p)
try{p=q
return p}catch(s){if(t._.b(A.ac(s))){if((this.c&1)!==0)throw A.h(A.aR("The error handler of Future.then must return a value of the returned future's type","onError"))
throw A.h(A.aR("The error handler of Future.catchError must return a value of the future's type","onError"))}else throw s}}}
A.K.prototype={
bF(a,b,c){var s,r=$.w
if(r===B.c){if(!t.C.b(b)&&!t.v.b(b))throw A.h(A.fB(b,"onError",u.c))}else b=A.jy(b,r)
s=new A.K(r,c.j("K<0>"))
this.af(new A.cA(s,3,a,b,this.$ti.j("@<1>").u(c).j("cA<1,2>")))
return s},
bb(a){this.a=this.a&1|16
this.c=a},
R(a){this.a=a.a&30|this.a&1
this.c=a.c},
af(a){var s=this,r=s.a
if(r<=3){a.a=s.c
s.c=a}else{if((r&4)!==0){r=s.c
if((r.a&24)===0){r.af(a)
return}s.R(r)}A.eR(null,null,s.b,new A.eh(s,a))}},
ar(a){var s,r,q,p,o,n=this,m={}
m.a=a
if(a==null)return
s=n.a
if(s<=3){r=n.c
n.c=a
if(r!=null){q=a.a
for(p=a;q!=null;p=q,q=o)o=q.a
p.a=r}}else{if((s&4)!==0){s=n.c
if((s.a&24)===0){s.ar(a)
return}n.R(s)}m.a=n.U(a)
A.eR(null,null,n.b,new A.ek(m,n))}},
T(){var s=this.c
this.c=null
return this.U(s)},
U(a){var s,r,q
for(s=a,r=null;s!=null;r=s,s=q){q=s.a
s.a=r}return r},
ah(a){var s,r=this
if(r.$ti.j("aX<1>").b(a))A.fi(a,r,!0)
else{s=r.T()
r.a=8
r.c=a
A.aJ(r,s)}},
b0(a){var s,r,q=this
if((a.a&16)!==0){s=q.b===a.b
s=!(s||s)}else s=!1
if(s)return
r=q.T()
q.R(a)
A.aJ(q,r)},
a0(a){var s=this.T()
this.bb(a)
A.aJ(this,s)},
b_(a){this.a^=2
A.eR(null,null,this.b,new A.ei(this,a))},
$iaX:1}
A.eh.prototype={
$0(){A.aJ(this.a,this.b)},
$S:1}
A.ek.prototype={
$0(){A.aJ(this.b,this.a.a)},
$S:1}
A.ej.prototype={
$0(){A.fi(this.a.a,this.b,!0)},
$S:1}
A.ei.prototype={
$0(){this.a.a0(this.b)},
$S:1}
A.en.prototype={
$0(){var s,r,q,p,o,n,m,l,k=this,j=null
try{q=k.a.a
j=q.b.b.bx(q.d)}catch(p){s=A.ac(p)
r=A.ap(p)
if(k.c&&k.b.a.c.a===s){q=k.a
q.c=k.b.a.c}else{q=s
o=r
if(o==null)o=A.f6(q)
n=k.a
n.c=new A.P(q,o)
q=n}q.b=!0
return}if(j instanceof A.K&&(j.a&24)!==0){if((j.a&16)!==0){q=k.a
q.c=j.c
q.b=!0}return}if(j instanceof A.K){m=k.b.a
l=new A.K(m.b,m.$ti)
j.bF(new A.eo(l,m),new A.ep(l),t.b9)
q=k.a
q.c=l
q.b=!1}},
$S:1}
A.eo.prototype={
$1(a){this.a.b0(this.b)},
$S:8}
A.ep.prototype={
$2(a,b){this.a.a0(new A.P(a,b))},
$S:15}
A.em.prototype={
$0(){var s,r,q,p,o,n
try{q=this.a
p=q.a
q.c=p.b.b.ab(p.d,this.b)}catch(o){s=A.ac(o)
r=A.ap(o)
q=s
p=r
if(p==null)p=A.f6(q)
n=this.a
n.c=new A.P(q,p)
n.b=!0}},
$S:1}
A.el.prototype={
$0(){var s,r,q,p,o,n,m,l=this
try{s=l.a.a.c
p=l.b
if(p.a.bt(s)&&p.a.e!=null){p.c=p.a.bn(s)
p.b=!1}}catch(o){r=A.ac(o)
q=A.ap(o)
p=l.a.a.c
if(p.a===r){n=l.b
n.c=p
p=n}else{p=r
n=q
if(n==null)n=A.f6(p)
m=l.b
m.c=new A.P(p,n)
p=m}p.b=!0}},
$S:1}
A.cx.prototype={}
A.eC.prototype={}
A.eu.prototype={
bB(a){var s,r,q
try{if(B.c===$.w){a.$0()
return}A.hn(null,null,this,a)}catch(q){s=A.ac(q)
r=A.ap(q)
A.eP(s,r)}},
bD(a,b){var s,r,q
try{if(B.c===$.w){a.$1(b)
return}A.ho(null,null,this,a,b)}catch(q){s=A.ac(q)
r=A.ap(q)
A.eP(s,r)}},
bE(a,b){return this.bD(a,b,t.z)},
aA(a){return new A.ev(this,a)},
bi(a,b){return new A.ew(this,a,b)},
by(a){if($.w===B.c)return a.$0()
return A.hn(null,null,this,a)},
bx(a){return this.by(a,t.z)},
bC(a,b){if($.w===B.c)return a.$1(b)
return A.ho(null,null,this,a,b)},
ab(a,b){var s=t.z
return this.bC(a,b,s,s)},
bA(a,b,c){if($.w===B.c)return a.$2(b,c)
return A.jz(null,null,this,a,b,c)},
bz(a,b,c){var s=t.z
return this.bA(a,b,c,s,s,s)},
bv(a){return a},
bu(a){var s=t.z
return this.bv(a,s,s,s)}}
A.ev.prototype={
$0(){return this.a.bB(this.b)},
$S:1}
A.ew.prototype={
$1(a){return this.a.bE(this.b,a)},
$S(){return this.c.j("~(0)")}}
A.eQ.prototype={
$0(){A.i4(this.a,this.b)},
$S:1}
A.be.prototype={
gaa(){return new A.bf(this,this.$ti.j("bf<1>"))},
a8(a){var s,r
if(typeof a=="string"&&a!=="__proto__"){s=this.b
return s==null?!1:s[a]!=null}else if(typeof a=="number"&&(a&1073741823)===a){r=this.c
return r==null?!1:r[a]!=null}else return this.b4(a)},
b4(a){var s=this.d
if(s==null)return!1
return this.F(this.am(s,a),a)>=0},
E(a,b){var s,r,q
if(typeof b=="string"&&b!=="__proto__"){s=this.b
r=s==null?null:A.fW(s,b)
return r}else if(typeof b=="number"&&(b&1073741823)===b){q=this.c
r=q==null?null:A.fW(q,b)
return r}else return this.b8(b)},
b8(a){var s,r,q=this.d
if(q==null)return null
s=this.am(q,a)
r=this.F(s,a)
return r<0?null:s[r+1]},
t(a,b,c){var s,r,q,p=this,o=p.d
if(o==null)o=p.d=A.iz()
s=A.f3(b)&1073741823
r=o[s]
if(r==null){A.fX(o,s,[b,c]);++p.a
p.e=null}else{q=p.F(r,b)
if(q>=0)r[q+1]=c
else{r.push(b,c);++p.a
p.e=null}}},
a9(a,b){var s,r,q,p,o,n=this,m=n.ai()
for(s=m.length,r=n.$ti.y[1],q=0;q<s;++q){p=m[q]
o=n.E(0,p)
b.$2(p,o==null?r.a(o):o)
if(m!==n.e)throw A.h(A.Q(n))}},
ai(){var s,r,q,p,o,n,m,l,k,j,i=this,h=i.e
if(h!=null)return h
h=A.fM(i.a,null,!1,t.z)
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
am(a,b){return a[A.f3(b)&1073741823]}}
A.bg.prototype={
F(a,b){var s,r,q
if(a==null)return-1
s=a.length
for(r=0;r<s;r+=2){q=a[r]
if(q==null?b==null:q===b)return r}return-1}}
A.bf.prototype={
gq(a){var s=this.a
return new A.cB(s,s.ai(),this.$ti.j("cB<1>"))}}
A.cB.prototype={
gl(){var s=this.d
return s==null?this.$ti.c.a(s):s},
k(){var s=this,r=s.b,q=s.c,p=s.a
if(r!==p.e)throw A.h(A.Q(p))
else if(q>=r.length){s.d=null
return!1}else{s.d=r[q]
s.c=q+1
return!0}}}
A.bh.prototype={
gq(a){var s=this,r=new A.aL(s,s.r,s.$ti.j("aL<1>"))
r.c=s.e
return r},
bj(a,b){var s,r
if(b!=="__proto__"){s=this.b
if(s==null)return!1
return s[b]!=null}else{r=this.b3(b)
return r}},
b3(a){var s=this.d
if(s==null)return!1
return this.F(s[B.d.gm(a)&1073741823],a)>=0},
a6(a,b){var s,r,q=this
if(typeof b=="string"&&b!=="__proto__"){s=q.b
return q.ae(s==null?q.b=A.fj():s,b)}else if(typeof b=="number"&&(b&1073741823)===b){r=q.c
return q.ae(r==null?q.c=A.fj():r,b)}else return q.aY(b)},
aY(a){var s,r,q=this,p=q.d
if(p==null)p=q.d=A.fj()
s=J.N(a)&1073741823
r=p[s]
if(r==null)p[s]=[q.a3(a)]
else{if(q.F(r,a)>=0)return!1
r.push(q.a3(a))}return!0},
ae(a,b){if(a[b]!=null)return!1
a[b]=this.a3(b)
return!0},
ao(){this.r=this.r+1&1073741823},
a3(a){var s,r=this,q=new A.er(a)
if(r.e==null)r.e=r.f=q
else{s=r.f
s.toString
q.c=s
r.f=s.b=q}++r.a
r.ao()
return q},
F(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.Y(a[r].a,b))return r
return-1}}
A.er.prototype={}
A.aL.prototype={
gl(){var s=this.d
return s==null?this.$ti.c.a(s):s},
k(){var s=this,r=s.c,q=s.a
if(s.b!==q.r)throw A.h(A.Q(q))
else if(r==null){s.d=null
return!1}else{s.d=r.a
s.c=r.b
return!0}}}
A.r.prototype={
gq(a){return new A.aC(a,a.length,A.aq(a).j("aC<r.E>"))},
X(a,b){return a[b]},
aM(a,b){return new A.W(a,b,A.aq(a).j("W<r.E>"))},
H(a,b,c){return new A.T(a,b,A.aq(a).j("@<r.E>").u(c).j("T<1,2>"))},
i(a){return A.fb(a,"[","]")}}
A.a4.prototype={
a9(a,b){var s,r,q,p
for(s=this.gaa(),s=s.gq(s),r=A.a8(this).y[1];s.k();){q=s.gl()
p=this.E(0,q)
b.$2(q,p==null?r.a(p):p)}},
i(a){return A.fN(this)},
$ia3:1}
A.dK.prototype={
$2(a,b){var s,r=this.a
if(!r.a)this.b.a+=", "
r.a=!1
r=this.b
s=A.o(a)
r.a=(r.a+=s)+": "
s=A.o(b)
r.a+=s},
$S:19}
A.aG.prototype={
H(a,b,c){return new A.ad(this,b,this.$ti.j("@<1>").u(c).j("ad<1,2>"))},
i(a){return A.fb(this,"{","}")},
$ii:1,
$ie:1}
A.bo.prototype={}
A.ax.prototype={
D(a,b){if(b==null)return!1
return b instanceof A.ax&&this.a===b.a},
gm(a){return B.b.gm(this.a)},
i(a){var s,r,q,p=this.a,o=p%36e8,n=B.b.au(o,6e7)
o%=6e7
s=n<10?"0":""
r=B.b.au(o,1e6)
q=r<10?"0":""
return""+(p/36e8|0)+":"+s+n+":"+q+r+"."+B.d.aI(B.b.i(o%1e6),6,"0")}}
A.p.prototype={
gN(){return A.ij(this)}}
A.bF.prototype={
i(a){var s=this.a
if(s!=null)return"Assertion failed: "+A.d0(s)
return"Assertion failed"}}
A.U.prototype={}
A.O.prototype={
gak(){return"Invalid argument"+(!this.a?"(s)":"")},
gaj(){return""},
i(a){var s=this,r=s.c,q=r==null?"":" ("+r+")",p=s.d,o=p==null?"":": "+p,n=s.gak()+q+o
if(!s.a)return n
return n+s.gaj()+": "+A.d0(s.gaF())},
gaF(){return this.b}}
A.cj.prototype={
gaF(){return this.b},
gak(){return"RangeError"},
gaj(){var s,r=this.e,q=this.f
if(r==null)s=q!=null?": Not less than or equal to "+A.o(q):""
else if(q==null)s=": Not greater than or equal to "+A.o(r)
else if(q>r)s=": Not in inclusive range "+A.o(r)+".."+A.o(q)
else s=q<r?": Valid value range is empty":": Only valid value is "+A.o(r)
return s}}
A.bd.prototype={
i(a){return"Unsupported operation: "+this.a}}
A.cu.prototype={
i(a){return"UnimplementedError: "+this.a}}
A.cq.prototype={
i(a){return"Bad state: "+this.a}}
A.bJ.prototype={
i(a){var s=this.a
if(s==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.d0(s)+"."}}
A.cd.prototype={
i(a){return"Out of Memory"},
gN(){return null},
$ip:1}
A.bb.prototype={
i(a){return"Stack Overflow"},
gN(){return null},
$ip:1}
A.eg.prototype={
i(a){return"Exception: "+this.a}}
A.d4.prototype={
i(a){var s=this.a,r=""!==s?"FormatException: "+s:"FormatException",q=this.b
if(q.length>78)q=B.d.aQ(q,0,75)+"..."
return r+"\n"+q}}
A.e.prototype={
H(a,b,c){return A.ig(this,b,A.a8(this).j("e.E"),c)},
i(a){return A.i5(this,"(",")")}}
A.ai.prototype={
i(a){return"MapEntry("+A.o(this.a)+": "+A.o(this.b)+")"}}
A.A.prototype={
gm(a){return A.j.prototype.gm.call(this,0)},
i(a){return"null"}}
A.j.prototype={$ij:1,
D(a,b){return this===b},
gm(a){return A.ch(this)},
i(a){return"Instance of '"+A.ci(this)+"'"},
gn(a){return A.hx(this)},
toString(){return this.i(this)}}
A.cD.prototype={
i(a){return""},
$iaI:1}
A.e_.prototype={
gbl(){var s,r=this.b
if(r==null)r=$.dR.$0()
s=r-this.a
if($.fy()===1e6)return s
return s*1000}}
A.cs.prototype={
i(a){var s=this.a
return s.charCodeAt(0)==0?s:s}}
A.f_.prototype={
$1(a){var s,r,q,p
if(A.hl(a))return a
s=this.a
if(s.a8(a))return s.E(0,a)
if(a instanceof A.a4){r={}
s.t(0,a,r)
for(s=a.gaa(),s=s.gq(s);s.k();){q=s.gl()
r[q]=this.$1(a.E(0,q))}return r}else if(t.f.b(a)){p=[]
s.t(0,a,p)
B.h.az(p,J.fA(a,this,t.z))
return p}else return a},
$S:20}
A.at.prototype={}
A.m.prototype={}
A.aT.prototype={}
A.aW.prototype={}
A.c0.prototype={}
A.aV.prototype={}
A.ck.prototype={}
A.bN.prototype={}
A.x.prototype={}
A.a0.prototype={}
A.y.prototype={}
A.a_.prototype={}
A.aH.prototype={}
A.ce.prototype={}
A.bO.prototype={}
A.bP.prototype={}
A.az.prototype={}
A.av.prototype={}
A.bR.prototype={}
A.bD.prototype={}
A.bQ.prototype={}
A.bM.prototype={}
A.c1.prototype={}
A.cc.prototype={}
A.cm.prototype={}
A.cg.prototype={}
A.cU.prototype={}
A.bn.prototype={
J(){var s,r,q,p,o,n
for(r=this.a,q=A.fY(r,r.r,r.$ti.c),p=q.$ti.c;q.k();){o=q.d
s=o==null?p.a(o):o
try{s.$0()}catch(n){}}if(r.a>0){r.b=r.c=r.d=r.e=r.f=null
r.a=0
r.ao()}}}
A.aK.prototype={}
A.eH.prototype={
$0(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5=this,a6=a5.a,a7=a6.a.$0(),a8=A.aB(t.N),a9=A.b([],t.r)
for(s=a7.length,r=t.M,a6=a6.b,q=a5.c,p=a5.b,o=a5.d,n=0;n<a7.length;a7.length===s||(0,A.M)(a7),++n){m=a7[n]
l=p.$1(m)
a8.a6(0,l)
if(q.a8(l)){k=q.E(0,l)
j=k.c
j.J()
i=A.bA(a6.$1(m),j)
for(h=k.b,g=0;f=h.length,g<f;++g){e=h[g]
if(g<i.length){d=i[g]
if(e!==d&&J.Y(e.parentNode,o))o.replaceChild(d,e)}else if(J.Y(e.parentNode,o))o.removeChild(e)}for(g=f;g<i.length;++g)o.appendChild(i[g])
c=new A.aK(i,j)
q.t(0,l,c)
a9.push(c)}else{b=new A.bn(A.aB(r))
a=new A.aK(A.bA(a6.$1(m),b),b)
q.t(0,l,a)
a9.push(a)}}a6=A.a8(q).j("ah<1>")
s=a6.j("W<e.E>")
a0=A.c_(new A.W(new A.ah(q,a6),new A.eI(a8),s),s.j("e.E"))
for(a6=a0.length,n=0;n<a0.length;a0.length===a6||(0,A.M)(a0),++n){a=q.bw(0,a0[n])
a.c.J()
for(s=a.b,r=s.length,a1=0;a1<s.length;s.length===r||(0,A.M)(s),++a1){a2=s[a1]
if(J.Y(a2.parentNode,o))o.removeChild(a2)}}for(a3=0;a3<a9.length;++a3)for(a6=a9[a3].b,s=a6.length,n=0;n<a6.length;a6.length===s||(0,A.M)(a6),++n){a2=a6[n]
a4=o.childNodes.item(a3)
if(a4!==a2)o.insertBefore(a2,a4)}},
$S:1}
A.eI.prototype={
$1(a){return!this.a.bj(0,a)},
$S:12}
A.eG.prototype={
$0(){this.a.$0()},
$S:2}
A.eF.prototype={
$0(){var s,r
this.a.$0()
for(s=this.b,r=new A.bZ(s,s.r,s.e);r.k();)r.d.c.J()
if(s.a>0){s.b=s.c=s.d=s.e=s.f=null
s.a=0
s.Z()}},
$S:1}
A.eL.prototype={
$0(){var s,r,q,p,o=this,n=o.a
n.J()
s=o.b.$0()
r=o.c
q=A.bA(r==null?t.c.a(s):r.$1(s),n)
n=o.d
n.textContent=""
for(r=q.length,p=0;p<q.length;q.length===r||(0,A.M)(q),++p)n.appendChild(q[p])},
$S:1}
A.eK.prototype={
$0(){this.a.$0()},
$S:2}
A.eJ.prototype={
$0(){this.a.$0()
this.b.J()},
$S:1}
A.eD.prototype={
$1(a){this.b.$1(A.jI(this.a,a))},
$S:29}
A.cH.prototype={
A(){var s=this,r=null,q="px-2 py-0.5 rounded bg-[#1E1E24] hover:bg-[#27272A] text-xs font-mono text-zinc-300 cursor-pointer",p="flex items-center gap-2",o="text-zinc-400",n=t.N,m=t.t
return A.cn(A.q(["id","benchmark"],n,n),A.b([A.d(A.b([A.a(u.a,"Real-Time Telemetry & Comparative Benchmarks"),A.d6(u.d,"Fine-Grained Signals vs VDOM Diffing"),A.aj("text-zinc-400 text-base leading-relaxed","Unlike React or Flutter which recreate virtual element trees on every state change, Bloom binds signals directly to individual DOM text nodes and attributes with zero reconciliation overhead.")],m),"text-center max-w-3xl mx-auto mb-12",r),A.d(A.b([A.d(A.b([A.d(A.b([A.E(A.b([new A.x(new A.cI(s)),new A.x(new A.cJ(s))],m),"px-4 py-2.5 rounded-lg font-medium text-xs flex items-center gap-2 cursor-pointer transition-all bg-indigo-600 hover:bg-indigo-500 text-white shadow-md shadow-indigo-600/20 active:scale-95",new A.cK(s),r),A.d(A.b([A.a("text-xs text-zinc-400 font-mono","Nodes:"),new A.x(new A.cM(s)),A.E(B.a,q,new A.cN(s),"-"),A.E(B.a,q,new A.cO(s),"+")],m),"flex items-center gap-3 bg-[#14141A] px-4 py-2 rounded-lg border border-[#27272A]",r)],m),"flex items-center gap-4 flex-wrap",r),A.d(A.b([A.d(A.b([A.a("w-2 h-2 rounded-full bg-emerald-400 animate-pulse",r),A.a(o,"FPS:"),new A.x(new A.cP(s))],m),p,r),A.d(A.b([A.a("w-2 h-2 rounded-full bg-indigo-400",r),A.a(o,"Patch Latency:"),new A.x(new A.cQ(s))],m),p,r),A.d(A.b([A.a(o,"Throughput:"),new A.x(new A.cR(s))],m),"flex items-center gap-2 bg-[#14141A] px-3 py-1 rounded-md border border-[#27272A]",r)],m),"flex items-center gap-6 font-mono text-xs flex-wrap",r)],m),"flex flex-col md:flex-row md:items-center justify-between gap-6 pb-6 border-b border-[#1E1E24]",r),A.d(A.b([A.d(A.b([new A.a0(new A.cS(s),new A.cT(),new A.cL(),t.R)],m),"grid grid-cols-2 sm:grid-cols-4 md:grid-cols-6 lg:grid-cols-12 gap-2.5",r)],m),"pt-6",r)],m),"rounded-2xl bg-[#101014] border border-[#1E1E24] p-6 sm:p-8 shadow-2xl overflow-hidden mb-12",r),A.d(A.b([A.d(A.b([A.d(A.b([A.f9("text-lg font-bold text-white","Benchmark Matrix: Web Frameworks Comparison"),A.aj("text-xs text-zinc-400 mt-0.5","Independent cold-start SSR latency and production JS gzip footprint benchmarks.")],m),r,r),A.a("text-xs font-mono px-3 py-1 rounded-full bg-[#14141A] text-indigo-400 border border-[#27272A]","Chart.js Native Binding")],m),"flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6",r),A.d(A.b([new A.y('<canvas id="perf-chart" class="w-full h-full"></canvas>')],m),"h-72 w-full relative",r)],m),"rounded-2xl bg-[#101014] border border-[#1E1E24] p-6 sm:p-8 shadow-2xl",r)],m),"py-20 px-6 max-w-7xl mx-auto")}}
A.cK.prototype={
$1(a){var s=this.a.a.r
s.sh(!s.gh())
return null},
$S:0}
A.cI.prototype={
$0(){return this.a.a.r.gh()?new A.y('<svg class="w-3.5 h-3.5 animate-spin" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"></path></svg>'):new A.y('<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>')},
$S:10}
A.cJ.prototype={
$0(){return A.a(null,this.a.a.r.gh()?"Pause Stress Ticker":"Resume Live Stress Ticker")},
$S:3}
A.cM.prototype={
$0(){return A.a("text-xs font-mono font-bold text-white",""+this.a.a.b.gh())},
$S:3}
A.cN.prototype={
$1(a){var s=this.a.a
return s.aL(B.b.aB(s.b.gh()-12,12,120))},
$S:0}
A.cO.prototype={
$1(a){var s=this.a.a
return s.aL(B.b.aB(s.b.gh()+12,12,120))},
$S:0}
A.cP.prototype={
$0(){return A.a("text-emerald-400 font-bold",""+this.a.a.c.gh())},
$S:3}
A.cQ.prototype={
$0(){return A.a("text-indigo-400 font-bold",A.o(this.a.a.d.gh())+" ms")},
$S:3}
A.cR.prototype={
$0(){return A.a("text-cyan-400 font-bold",""+this.a.a.e.gh()+" patches/s")},
$S:3}
A.cS.prototype={
$0(){return this.a.a.f.gh()},
$S:16}
A.cT.prototype={
$1(a){var s=null,r=""+a.c,q=t.t
return A.d(A.b([A.d(A.b([A.a(s,"#"+a.a),A.a("text-zinc-400",r+"%")],q),"flex items-center justify-between text-[10px] font-mono text-zinc-500 mb-1",s),A.a("text-base font-mono font-extrabold text-indigo-400 my-0.5 tracking-tight",""+a.b),A.d(A.b([A.d(B.a,"h-full bg-gradient-to-r from-indigo-500 to-violet-500 rounded-full transition-all duration-75","width: "+r+"%;")],q),"w-full h-1 bg-[#1E1E24] rounded-full overflow-hidden mt-1.5",s)],q),"p-3 rounded-xl bg-[#14141A] border border-[#27272A] hover:border-indigo-500/50 flex flex-col justify-between transition-colors shadow-sm",s)},
$S:17}
A.cL.prototype={
$1(a){return""+a.a},
$S:18}
A.cV.prototype={
A(){var s=this,r=null,q="flex items-center gap-2",p=t.N,o=t.t
return A.cn(A.q(["id","code"],p,p),A.b([A.d(A.b([A.a(u.a,"Developer Ergonomics"),A.d6(u.d,"Clean, Declarative Pure Dart"),A.aj("text-zinc-400 text-base leading-relaxed","No HTML templates, no JSX, and zero dynamic code generation at runtime. Every component is a strongly-typed, tree-shakeable AST descriptor tree.")],o),"text-center max-w-3xl mx-auto mb-12",r),A.d(A.b([A.d(A.b([A.d(A.b([A.a("w-3 h-3 rounded-full bg-[#EF4444]/80 border border-[#DC2626]",r),A.a("w-3 h-3 rounded-full bg-[#F59E0B]/80 border border-[#D97706]",r),A.a("w-3 h-3 rounded-full bg-[#10B981]/80 border border-[#059669]",r)],o),q,r),A.d(A.b([s.a5("main.dart","UI Component"),s.a5("ssr_router.dart","Server SSR"),s.a5("bloom.yaml","NPM Toolchain")],o),q,r),A.E(A.b([new A.y('<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>'),A.a(r,"Copy")],o),"text-xs font-mono px-2.5 py-1 rounded bg-[#14141A] hover:bg-[#1E1E24] text-zinc-400 hover:text-white border border-[#27272A] flex items-center gap-1.5 transition-colors cursor-pointer",new A.cY(s),r)],o),"px-4 py-3 bg-[#101014] border-b border-[#1E1E24] flex items-center justify-between",r),A.d(A.b([new A.x(new A.cZ(s))],o),"p-6 font-mono text-xs sm:text-sm leading-relaxed overflow-x-auto text-zinc-300 custom-scrollbar bg-[#09090B]",r)],o),"max-w-4xl mx-auto rounded-2xl bg-[#09090B] border border-[#1E1E24] shadow-2xl overflow-hidden",r)],o),"py-20 px-6 max-w-7xl mx-auto")},
a5(a,b){return new A.x(new A.cX(this,a,b))},
ba(a){var s="flex",r="flex-1 pl-4",q="text-zinc-500 italic",p="text-[#818CF8] font-bold",o="import",n=null,m=" 'package:bloom_js_native/bloom_js_native.dart';\n",l="text-[#C084FC] font-bold",k=" main() {\n",j="      children: [\n",i="      ],\n",h="text-[#38BDF8]",g=t.t
switch(a){case"ssr_router.dart":return A.d(A.b([this.a1(18),A.dO(A.b([A.a(q,"// apps/server/bin/server.dart\n"),A.a(p,o),A.a(n," 'package:bloom_framework/bloom.dart';\n"),A.a(p,o),A.a(n,m),A.a(p,o),A.a(n," 'package:bloom_seo/bloom_seo.dart';\n\n"),A.a(l,"void"),A.a(n,k),A.a(n,"  final router = BloomApiRouter();\n\n"),A.a(q,"  // Unified Sub-Millisecond SSR Route (<1ms response)\n"),A.a(n,"  router.ssr(\n"),A.a(n,"    '/',\n"),A.a(n,"    (req) => Div(\n"),A.a(n,"      className: 'min-h-screen bg-black text-white p-12',\n"),A.a(n,j),A.a(n,"        H1(className: 'text-4xl font-bold', text: 'Bloom SSR'),\n"),A.a(n,"        P(text: 'Zero JavaScript loaded on initial paint.'),\n"),A.a(n,i),A.a(n,"    ),\n"),A.a(n,"    head: (req) => HeadManager(initialTitle: 'Bloom Fast SSR'),\n"),A.a(n,"  );\n\n"),A.a(n,"  router.listen(port: 8080);\n"),A.a(n,"}\n")],g),r)],g),s,n)
case"bloom.yaml":return A.d(A.b([this.a1(15),A.dO(A.b([A.a(q,"# bloom.yaml \u2014 Zero Configuration Toolchain\n"),A.a(p,"name"),A.a(n,": showcase_app\n"),A.a(p,"target"),A.a(n,": web_dom\n\n"),A.a("text-[#F472B6] font-bold","npm_packages"),A.a(n,":\n"),A.a(h,"  three"),A.a(n,":\n"),A.a(n,"    npm_name: three\n"),A.a(n,"    version: 0.160.0\n"),A.a(n,"    vendor_file: web/vendor/three.min.js\n"),A.a(n,"    dart_binding: lib/plugins/three_js.dart\n\n"),A.a(h,"  canvas-confetti"),A.a(n,":\n"),A.a(n,"    npm_name: canvas-confetti\n"),A.a(n,"    version: 1.9.3\n"),A.a(n,"    vendor_file: web/vendor/canvas-confetti.min.js\n")],g),r)],g),s,n)
default:return A.d(A.b([this.a1(24),A.dO(A.b([A.a(q,"// lib/main.dart \u2014 Fine-Grained Signals UI\n"),A.a(p,o),A.a(n,m),A.a(p,o),A.a(n," 'package:bloom_js_native/browser.dart';\n\n"),A.a(l,"void"),A.a(n,k),A.a(n,"  final count = signal("),A.a("text-[#FBBF24]","0"),A.a(n,");\n"),A.a(n,"  final isEven = computed(() => count.value.isEven);\n\n"),A.a(n,"  mount(\n"),A.a(n,"    Div(\n"),A.a(n,"      className: 'p-6 bg-zinc-950 rounded-2xl border border-zinc-800 max-w-md mx-auto',\n"),A.a(n,j),A.a(n,"        Live(() => H2(\n"),A.a(n,"          className: 'text-2xl font-bold text-white',\n"),A.a(n,'          text: \'Count: ${count.value} (${isEven.value ? "Even" : "Odd"})\',\n'),A.a(n,"        )),\n"),A.a(n,"        Button(\n"),A.a(n,"          className: 'mt-4 px-4 py-2 bg-indigo-600 hover:bg-indigo-500 text-white rounded-lg',\n"),A.a(n,"          onClick: (_) => count.value++,\n"),A.a(n,"          text: 'Increment Signal',\n"),A.a(n,"        ),\n"),A.a(n,i),A.a(n,"    ),\n"),A.a(n,"    '#app',\n"),A.a(n,"  );\n"),A.a(n,"}\n")],g),r)],g),s,n)}},
a1(a){var s,r,q,p=J.dF(a,t.N)
for(s=0;s<a;s=r){r=s+1
p[s]=B.d.aI(""+r,2," ")}q=t.t
return A.d(A.b([A.dO(A.b([A.a(null,B.h.bs(p,"\n"))],q),null)],q),"select-none pr-4 text-right border-r border-[#1E1E24] text-zinc-600 font-mono text-xs sm:text-sm",null)}}
A.cY.prototype={
$1(a){return this.a.a.M("Snippet copied to clipboard!")},
$S:0}
A.cZ.prototype={
$0(){var s=this.a
return s.ba(s.a.a.gh())},
$S:4}
A.cX.prototype={
$0(){var s=this.a,r=this.b
return A.E(B.a,"px-3 py-1.5 text-xs font-mono rounded-md transition-all cursor-pointer "+(s.a.a.gh()===r?"bg-[#1E1E24] text-white font-semibold shadow-sm border border-[#27272A]":"text-zinc-500 hover:text-zinc-300"),new A.cW(s,r),this.c)},
$S:11}
A.cW.prototype={
$1(a){this.a.a.a.sh(this.b)
return null},
$S:0}
A.d1.prototype={
P(a,b,c,d){var s=null,r=t.t
return A.d(A.b([A.d(A.b([A.d(A.b([A.d(A.b([new A.y('<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">'+b+"</svg>")],r),"w-12 h-12 rounded-xl bg-[#14141A] border border-[#27272A] flex items-center justify-center text-indigo-400 group-hover:text-white group-hover:bg-indigo-600 transition-colors",s),A.a("text-xs font-mono px-2.5 py-1 rounded-full bg-[#14141A] text-zinc-400 border border-[#27272A]",c)],r),"flex items-center justify-between mb-6",s),A.f9("text-xl font-bold text-white mb-3 tracking-tight",d),A.aj("text-zinc-400 text-sm leading-relaxed",a)],r),s,s)],r),"group p-8 rounded-2xl bg-[#101014] border border-[#1E1E24] hover:border-indigo-500/40 transition-all duration-300 relative overflow-hidden flex flex-col justify-between shadow-lg",s)}}
A.d7.prototype={
A(){var s=this,r=null,q=t.t,p=A.d(A.b([new A.y('<canvas id="three-hero-canvas" class="w-full h-full max-w-5xl max-h-[640px]" style="display: block; width: 100%; height: 100%;"></canvas>')],q),"absolute inset-0 pointer-events-none flex items-center justify-center opacity-70 z-0",r),o=A.d(A.b([A.a("w-2 h-2 rounded-full bg-indigo-500 animate-pulse",r),A.a(r,"Bloom 1.0 \u2014 The Fine-Grained Web Architecture for Dart")],q),"inline-flex items-center gap-2.5 px-4 py-1.5 rounded-full bg-[#14141A]/90 border border-indigo-500/30 text-xs font-medium text-zinc-300 mb-8 shadow-lg shadow-indigo-500/10 backdrop-blur-sm",r),n=A.b([A.a(r,"Pure Dart on the DOM.\n"),A.a("bg-gradient-to-r from-indigo-400 via-violet-300 to-cyan-300 bg-clip-text text-transparent drop-shadow-sm","0kB Flutter Runtime.")],q)
return A.cn(r,A.b([p,A.d(A.b([o,new A.bO("h1",r,"text-5xl sm:text-6xl md:text-7xl font-extrabold tracking-tight text-white mb-6 leading-[1.1]",r,r,A.a9(r,r,r,r,r,r,r),n),A.aj("max-w-2xl text-lg sm:text-xl text-zinc-400 mb-10 leading-relaxed font-normal","Dart owns reactivity, compilation, and tooling. The browser owns rendering. Surgical ESM imports via Bun with sub-millisecond SSR execution."),A.d(A.b([A.E(A.b([A.a("text-xs font-mono text-zinc-500 select-none","$"),A.a("text-sm font-mono text-zinc-200 font-medium","bloom create my_app --target=web_dom"),new A.x(new A.d8(s))],q),"group px-5 py-3.5 rounded-xl bg-[#14141A] hover:bg-[#1E1E24] border border-[#27272A] hover:border-indigo-500/50 flex items-center gap-3 transition-all cursor-pointer shadow-xl shadow-black/60 active:scale-95",new A.d9(s),r),A.as(A.b([new A.y('<svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24"><path fill-rule="evenodd" clip-rule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.53 1.032 1.53 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"/></svg>'),A.a(r,"Star on GitHub")],q),"px-6 py-3.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-semibold flex items-center gap-2 transition-all shadow-lg shadow-indigo-600/30 cursor-pointer active:scale-95","https://github.com/Chidi09/Bloom",r)],q),"flex flex-col sm:flex-row items-center gap-4 mb-16 w-full justify-center",r),A.d(A.b([s.S("< 1ms","SSR HTML Baseline","text-indigo-400"),s.S("82 kB","Production Bundle","text-violet-400"),s.S("0 kB","Flutter Engine","text-cyan-400"),s.S("100%","Fine-Grained Signals","text-emerald-400")],q),"grid grid-cols-2 sm:grid-cols-4 gap-4 w-full pt-8 border-t border-[#1E1E24]",r)],q),"relative max-w-5xl mx-auto text-center flex flex-col items-center z-10",r)],q),"relative pt-24 pb-20 px-6 overflow-hidden")},
S(a,b,c){return A.d(A.b([A.a("text-2xl sm:text-3xl font-extrabold font-mono mb-1 "+c+" tracking-tight",a),A.a("text-xs text-zinc-400 font-medium",b)],t.t),"p-4 rounded-xl bg-[#101014]/90 border border-[#1E1E24] text-center flex flex-col items-center justify-center backdrop-blur-sm shadow-md",null)}}
A.d9.prototype={
$1(a){return this.a.a.aJ()},
$S:0}
A.d8.prototype={
$0(){return this.a.a.x.gh()?new A.y('<svg class="w-4 h-4 text-emerald-400 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7"/></svg>'):new A.y('<svg class="w-4 h-4 text-zinc-400 group-hover:text-white ml-2 transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>')},
$S:10}
A.dd.prototype={
gbr(a){var s=this.f
return s===$?this.f=A.fs(new A.dD(this),t.y):s},
gaG(){var s=this.x
return s===$?this.x=A.fs(new A.dC(this),t.y):s},
gaH(){var s=this.y
return s===$?this.y=A.fs(new A.dE(this),t.y):s},
A(){var s=this,r=null,q=t.N,p=t.t
return A.cn(A.q(["id","sandbox"],q,q),A.b([A.d(A.b([A.a(u.a,"Interactive Component Lab"),A.d6(u.d,"Test-Drive Bloom Reactivity Live"),A.aj("text-zinc-400 text-base leading-relaxed","Every interaction below runs 100% fine-grained Bloom signals compiled from pure Dart. No virtual DOM diffing, no state loss.")],p),"text-center max-w-3xl mx-auto mb-12",r),A.d(A.b([A.d(A.b([s.V(0,"Keyed Reactive List"),s.V(1,"Signal Counter"),s.V(2,"Live Form Validation"),s.V(3,"Confetti Particle Cannon")],p),"flex items-center gap-2 pb-6 border-b border-[#1E1E24] overflow-x-auto custom-scrollbar",r),A.d(A.b([new A.x(new A.dB(s))],p),"pt-6",r)],p),"max-w-4xl mx-auto rounded-2xl bg-[#101014] border border-[#1E1E24] p-6 sm:p-8 shadow-2xl",r)],p),"py-20 px-6 max-w-7xl mx-auto")},
V(a,b){return new A.x(new A.dr(this,a,b))},
bg(){var s=this,r=null,q=t.t
return A.d(A.b([A.d(A.b([A.fa("flex-1 bg-[#14141A] border border-[#27272A] rounded-xl px-4 py-2.5 text-sm text-white focus:outline-none focus:border-indigo-500 transition-colors",new A.dw(s),"Add new task...",r),A.E(B.a,"px-5 py-2.5 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl text-xs font-semibold cursor-pointer transition-colors shadow-md active:scale-95",new A.dx(s),"Add Task")],q),"flex gap-3",r),A.d(A.b([new A.a0(new A.dy(s),new A.dz(s),new A.dA(),t.d)],q),"space-y-2 pt-2",r)],q),"space-y-4 max-w-xl mx-auto",r)},
b5(){var s=this,r=t.t
return A.d(A.b([A.d(A.b([A.a("text-xs font-mono text-zinc-500 uppercase tracking-widest","Signal Value"),new A.x(new A.dg(s)),new A.x(new A.dh(s))],r),"p-6 rounded-2xl bg-[#14141A] border border-[#27272A]",null),A.d(A.b([A.E(B.a,"px-5 py-2.5 rounded-xl bg-[#1E1E24] hover:bg-[#27272A] text-white font-mono text-sm cursor-pointer border border-[#27272A] active:scale-95",new A.di(s),"- Decrement"),A.E(B.a,"px-5 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-mono text-sm cursor-pointer shadow-md shadow-indigo-600/20 active:scale-95",new A.dj(s),"+ Increment")],r),"flex justify-center gap-3",null)],r),"text-center py-6 max-w-sm mx-auto space-y-6",null)},
b7(){var s=this,r="space-y-1.5",q="text-xs font-medium text-zinc-300",p="w-full bg-[#14141A] border border-[#27272A] rounded-xl px-4 py-2.5 text-sm text-white focus:outline-none focus:border-indigo-500",o=null,n=t.t
return A.d(A.b([A.d(A.b([A.a(q,"Email Address"),A.fa(p,new A.dk(s),"alex@bloom.dev",o),new A.x(new A.dl(s))],n),r,o),A.d(A.b([A.a(q,"Password (min 8 chars)"),A.fa(p,new A.dm(s),"\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022","password"),new A.x(new A.dn(s))],n),r,o),A.E(B.a,"w-full py-3 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold transition-all cursor-pointer shadow-lg shadow-indigo-600/25 mt-4 active:scale-95",new A.dp(s),"Validate Form State")],n),"max-w-md mx-auto space-y-4 py-2",o)},
b2(){var s=t.t
return A.d(A.b([A.aj("text-zinc-400 text-sm leading-relaxed","Trigger multi-stage ESM particles powered by canvas-confetti native JS bindings."),A.d(A.b([A.E(B.a,"px-5 py-3 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold transition-all cursor-pointer shadow-lg shadow-indigo-600/30 active:scale-95",new A.de(),"Center Explosion"),A.E(B.a,"px-5 py-3 rounded-xl bg-violet-600 hover:bg-violet-500 text-white text-xs font-bold transition-all cursor-pointer shadow-lg shadow-violet-600/30 active:scale-95",new A.df(),"Dual Cannons")],s),"flex justify-center gap-4 flex-wrap",null)],s),"text-center py-8 space-y-6 max-w-md mx-auto",null)}}
A.dD.prototype={
$0(){return(this.a.e.gh()&1)===0},
$S:5}
A.dC.prototype={
$0(){var s=A.io("^[\\w-\\.]+@([\\w-]+\\.)+[\\w-]{2,4}$"),r=this.a.r.gh()
return s.b.test(r)},
$S:5}
A.dE.prototype={
$0(){return this.a.w.gh().length>=8},
$S:5}
A.dB.prototype={
$0(){var s=this.a
switch(s.b.gh()){case 1:return s.b5()
case 2:return s.b7()
case 3:return s.b2()
default:return s.bg()}},
$S:4}
A.dr.prototype={
$0(){var s=this.a,r=this.b
return A.E(B.a,"px-4 py-2 text-xs font-medium rounded-lg transition-all cursor-pointer whitespace-nowrap "+(s.b.gh()===r?"bg-indigo-600 text-white shadow-md shadow-indigo-600/20":"bg-[#14141A] hover:bg-[#1E1E24] text-zinc-400 hover:text-white border border-[#27272A]"),new A.dq(s,r),this.c)},
$S:11}
A.dq.prototype={
$1(a){var s=this.b
this.a.b.sh(s)
return s},
$S:0}
A.dw.prototype={
$1(a){var s=a.b
if(s==null)s=""
this.a.d=s},
$S:0}
A.dx.prototype={
$1(a){var s,r,q,p=this.a,o=B.d.aK(p.d)
if(o.length!==0){s=p.c
r=A.c_(s.gh(),t.V)
r.push(new A.a6(!1,B.b.i(Date.now()),o))
s.sh(r)
p.d=""
q=v.G.document.querySelector("#sandbox input")
if(q!=null)q.value=""
A.aw(0.5,0.5)}},
$S:0}
A.dy.prototype={
$0(){return this.a.c.gh()},
$S:22}
A.dz.prototype={
$1(a){var s=null,r=a.a,q=r?"bg-indigo-600 border-indigo-500 text-white":"border-zinc-700 hover:border-zinc-500",p=this.a,o=t.t,n=A.b([],o)
if(r)n.push(new A.y('<svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"/></svg>'))
q=A.E(n,"w-5 h-5 rounded-md flex items-center justify-center border transition-colors cursor-pointer "+q,new A.du(p,a),s)
return A.d(A.b([A.d(A.b([q,A.a("text-sm "+(r?"line-through text-zinc-500":"text-zinc-200"),a.c)],o),"flex items-center gap-3",s),A.E(A.b([new A.y('<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/></svg>')],o),"text-xs text-zinc-500 hover:text-red-400 transition-colors p-1 cursor-pointer",new A.dv(p,a),s)],o),"p-3.5 rounded-xl bg-[#14141A] border border-[#27272A] flex items-center justify-between transition-all hover:border-zinc-700",s)},
$S:23}
A.du.prototype={
$1(a){var s=this.a.c,r=this.b,q=J.fA(s.gh(),new A.dt(r),t.V)
q=A.c_(q,q.$ti.j("R.E"))
s.sh(q)
if(!r.a)A.aw(0.5,0.5)},
$S:0}
A.dt.prototype={
$1(a){var s=a.b
return s===this.a.b?new A.a6(!a.a,s,a.c):a},
$S:24}
A.dv.prototype={
$1(a){var s=this.a.c,r=J.hV(s.gh(),new A.ds(this.b))
r=A.c_(r,r.$ti.j("e.E"))
s.sh(r)
return r},
$S:0}
A.ds.prototype={
$1(a){return a.b!==this.a.b},
$S:25}
A.dA.prototype={
$1(a){return a.b},
$S:26}
A.dg.prototype={
$0(){return A.f9("text-5xl font-extrabold font-mono text-white mt-2 mb-1",""+this.a.e.gh())},
$S:27}
A.dh.prototype={
$0(){var s=this.a.gbr(0),r=s.gh()?"bg-emerald-500/10 text-emerald-400 border border-emerald-500/20":"bg-violet-500/10 text-violet-400 border border-violet-500/20"
s=s.gh()?"Even Number":"Odd Number"
return A.a("text-xs font-mono px-2.5 py-0.5 rounded-full "+r,s)},
$S:3}
A.di.prototype={
$1(a){var s=this.a.e,r=s.gh()
s.sh(r-1)
return r},
$S:0}
A.dj.prototype={
$1(a){var s=this.a.e,r=s.gh()
s.sh(r+1)
return r},
$S:0}
A.dk.prototype={
$1(a){var s=a.b
if(s==null)s=""
this.a.r.sh(s)
return s},
$S:0}
A.dl.prototype={
$0(){var s,r=this.a
if(r.r.gh().length===0)r=B.f
else{r=r.gaG()
s=r.gh()?"text-emerald-400":"text-amber-400"
r=r.gh()?"\u2713 Valid email syntax":"\u26a0 Invalid email address"
r=A.a("text-xs font-mono "+s,r)}return r},
$S:4}
A.dm.prototype={
$1(a){var s=a.b
if(s==null)s=""
this.a.w.sh(s)
return s},
$S:0}
A.dn.prototype={
$0(){var s,r=this.a
if(r.w.gh().length===0)r=B.f
else{r=r.gaH()
s=r.gh()?"text-emerald-400":"text-amber-400"
r=r.gh()?"\u2713 Strong password length":"\u26a0 Requires at least 8 characters"
r=A.a("text-xs font-mono "+s,r)}return r},
$S:4}
A.dp.prototype={
$1(a){var s=this.a,r=s.gaG().gh()&&s.gaH().gh()
s=s.a
if(r){s.M("Validation Success! Account Ready.")
A.aw(0.5,0.5)}else s.M("Please fulfill validation requirements.")},
$S:0}
A.de.prototype={
$1(a){return A.aw(0.5,0.5)},
$S:0}
A.df.prototype={
$1(a){A.aw(0.2,0.6)
A.aw(0.8,0.6)},
$S:0}
A.dL.prototype={
A(){var s=null,r="hover:text-white transition-colors",q=t.t
return new A.bQ("header",s,"sticky top-0 z-50 w-full border-b border-[#1E1E24] bg-[#09090B]/85 backdrop-blur-md",s,s,s,A.b([A.d(A.b([A.d(A.b([A.d(A.b([new A.y('<svg class="w-5 h-5 text-white" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">\n                      <polygon points="12 2 2 7 12 12 22 7 12 2"></polygon>\n                      <polyline points="2 17 12 22 22 17"></polyline>\n                      <polyline points="2 12 12 17 22 12"></polyline>\n                    </svg>')],q),"relative w-9 h-9 rounded-xl bg-gradient-to-br from-indigo-500 via-indigo-600 to-violet-700 p-0.5 shadow-lg shadow-indigo-500/25 flex items-center justify-center",s),A.d(A.b([A.a("font-extrabold text-lg text-white tracking-tight","Bloom"),A.a("text-[11px] font-mono font-semibold px-2 py-0.5 rounded-md bg-[#14141A] text-indigo-400 border border-indigo-500/30","JS Native")],q),"flex items-center gap-2.5",s)],q),"flex items-center gap-3.5",s),new A.cc("nav",s,"hidden md:flex items-center gap-8 text-sm text-zinc-400 font-medium",s,s,s,A.b([A.as(B.a,r,"#features","Architecture"),A.as(B.a,r,"#benchmark","Telemetry Benchmark"),A.as(B.a,r,"#code","Code Showcase"),A.as(B.a,r,"https://github.com/Chidi09/Bloom","Documentation")],q)),A.d(A.b([A.E(A.b([new A.y('<svg class="w-3.5 h-3.5 text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>'),A.a(s,"bloom create")],q),"px-3.5 py-1.5 text-xs font-mono rounded-lg bg-[#14141A] hover:bg-[#1E1E24] text-zinc-300 border border-[#27272A] flex items-center gap-2 transition-all cursor-pointer shadow-sm active:scale-95",new A.dM(this),s)],q),"flex items-center gap-4",s)],q),"max-w-7xl mx-auto px-6 h-16 flex items-center justify-between",s)],q))}}
A.dM.prototype={
$1(a){return this.a.a.aJ()},
$S:0}
A.f0.prototype={
$0(){var s=this.a.w.gh()
if(s==null)return B.f
return A.d(A.b([new A.y('<svg class="w-4 h-4 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>'),A.a("text-xs font-mono text-zinc-200 font-medium",s)],t.t),"fixed bottom-6 right-6 z-50 px-4 py-3 rounded-xl bg-[#14141A] border border-[#27272A] shadow-2xl flex items-center gap-3 animate-bounce",null)},
$S:4}
A.f1.prototype={
$1(a){var s,r=v.G,q=r.document.getElementById("three-hero-canvas")
if(q!=null)new A.e0(q).bo()
s=r.document.getElementById("perf-chart")
if(s!=null)A.hY(s)},
$S:28}
A.e0.prototype={
bo(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6,a7,a8,a9=this
try{a2=a9.a
s=a2.getBoundingClientRect()
if(s.width>0)a3=s.width
else a3=a2.clientWidth>0?a2.clientWidth:900
r=a3
if(s.height>0)a4=s.height
else a4=a2.clientHeight>0?a2.clientHeight:600
q=a4
a5=v.G
p=new a5.THREE.Scene()
o=new a5.THREE.PerspectiveCamera(45,r/q,0.1,1000)
o.position.saN(6)
a6=t.N
a7=t.z
n=A.aM(A.bB(A.q(["canvas",a2,"alpha",!0,"antialias",!0],a6,a7)))
m=new a5.THREE.WebGLRenderer(n)
m.setSize(r,q)
m.setPixelRatio(a5.window.devicePixelRatio)
l=new a5.THREE.Group()
p.add(l)
k=new a5.THREE.IcosahedronGeometry(1.8,2)
j=A.aM(A.bB(A.q(["color",6514417,"wireframe",!0,"transparent",!0,"opacity",0.45],a6,a7)))
i=new a5.THREE.MeshBasicMaterial(j)
h=new a5.THREE.Mesh(k,i)
l.add(h)
g=new a5.THREE.IcosahedronGeometry(1.1,1)
f=A.aM(A.bB(A.q(["color",9133302,"wireframe",!0,"transparent",!0,"opacity",0.3],a6,a7)))
e=new a5.THREE.MeshBasicMaterial(f)
d=new a5.THREE.Mesh(g,e)
l.add(d)
c=new a5.THREE.TorusGeometry(2.4,0.015,16,100)
b=A.aM(A.bB(A.q(["color",440020,"wireframe",!0,"transparent",!0,"opacity",0.2],a6,a7)))
a=new a5.THREE.MeshBasicMaterial(b)
a0=new a5.THREE.Mesh(c,a)
a0.rotation.sC(1.0471975511965976)
l.add(a0)
a9.b=!0
a5.window.onmousemove=A.bw(new A.e2(a9))
a1=new A.e1(a9,h,d,a0,l,m,p,o)
a5.window.requestAnimationFrame(A.bw(a1))
a5.window.onresize=A.bw(new A.e3(a9,o,m))}catch(a8){}}}
A.e2.prototype={
$1(a){var s=this.a,r=v.G
s.c=a.clientX/r.window.innerWidth*2-1
s.d=-(a.clientY/r.window.innerHeight)*2+1},
$S:7}
A.e1.prototype={
$1(a){var s,r=this
if(!r.a.b)return
s=r.b.rotation
s.sC(s.gC().K(0,0.002))
s=r.b.rotation
s.sI(s.gI().K(0,0.0035))
s=r.c.rotation
s.sC(s.gC().O(0,0.003))
s=r.c.rotation
s.sI(s.gI().O(0,0.0045))
s=r.d.rotation
s.saN(s.gaN().K(0,0.0015))
s=r.e.rotation
s.sI(s.gI().K(0,B.e.O(r.a.c*0.4,r.e.rotation.gI())*0.05))
s=r.e.rotation
s.sC(s.gC().K(0,B.e.O(-r.a.d*0.4,r.e.rotation.gC())*0.05))
r.f.render(r.r,r.w)
v.G.window.requestAnimationFrame(A.bw(r))},
$S:30}
A.e3.prototype={
$1(a){var s,r,q,p=this.a
if(!p.b)return
p=p.a
s=p.getBoundingClientRect()
r=s.width>0?s.width:p.clientWidth
q=s.height>0?s.height:p.clientHeight
if(r>0&&q>0){p=this.b
p.aspect=r/q
p.updateProjectionMatrix()
this.c.setSize(r,q)}},
$S:7}
A.C.prototype={}
A.dU.prototype={
aL(a){var s,r,q
this.b.sh(a)
s=J.dF(a,t.W)
for(r=0;r<a;r=q){q=r+1
s[r]=new A.C(q,(r*37+100)%999,B.b.L(r*17,100))}this.f.sh(s)},
aJ(){this.x.sh(!0)
this.M("Copied: bloom create my_app --target=web_dom")
A.aw(0.5,0.3)
A.fJ(B.m,new A.dY(this),t.P)},
M(a){this.w.sh(a)
A.fJ(B.m,new A.dX(this,a),t.P)},
bf(){A.iu(B.y,new A.dW(this))}}
A.dY.prototype={
$0(){this.a.x.sh(!1)},
$S:2}
A.dX.prototype={
$0(){var s=this.a.w
if(s.gh()===this.b)s.sh(null)},
$S:2}
A.dW.prototype={
$1(a){var s,r,q,p,o=this.a
if(o.r.gh()){++o.z
s=new A.e_()
$.fy()
r=$.dR.$0()
s.a=r
s.b=null
q=o.b.gh()
o.f.sh(A.ie(q,new A.dV(o),t.W))
r=$.dR.$0()
s.b=r
p=s.gbl()/1000
o.d.sh(A.jP(B.e.bG(p<0.05?0.05:p,2)))
o.e.sh(q*31)}},
$S:31}
A.dV.prototype={
$1(a){var s=this.a.z
return new A.C(a+1,B.b.L(s*9+a*47,999),B.b.L(s*3+a*11,100))},
$S:32}
A.aS.prototype={
a4(){var s,r,q,p,o,n,m,l=this,k=l.at&=4294967293
if((k&1)!==0)return!1
if((k&36)===32)return!0
k&=4294967291
l.at=k
p=l.as
o=$.eN
if(p===o)return!0
l.as=o
l.at=k|1
s=A.hk(l)
if(l.e>0&&!s){l.at&=4294967294
return!0}n=$.D
try{A.hm(l)
$.D=l
r=l.z.$0()
if((l.at&16)!==0||s||l.e===0){if(l.e!==0){k=l.y
k===$&&A.ab()
k=!J.Y(r,k)}else k=!0
if(k){k=l.e
if(k!==0)l.y===$&&A.ab()
l.y=r
l.at&=4294967279
l.e=k+1}}}catch(m){q=A.ac(m)
l.ax=q
l.at|=16;++l.e}$.D=n
A.hd(l)
l.at&=4294967294
return!0},
W(a){var s,r=this
if(r.r==null){r.at|=36
for(s=r.Q;s!=null;s=s.c)s.a.W(s)}r.aS(a)},
G(a){var s=this
if(s.r!=null){s.ac(a)
if(s.r==null){s.at&=4294967263
for(a=s.Q;a!=null;a=a.c)a.a.G(a)}}},
ap(){var s=this.at
if((s&2)===0){this.at=s|6
this.aq()}},
gh(){var s,r,q=this
if(q.b){A.hB("computed warning: ["+q.d+"|"+A.o(q.c)+"] has been read after disposed: "+A.ff().i(0))
s=q.y
s===$&&A.ab()
return s}if((q.at&1)!==0)throw A.h(new A.ay())
r=A.h8(q)
q.a4()
if(r!=null)r.r=q.e
if((q.at&16)!==0){s=q.ax
s.toString
throw A.h(s)}s=q.y
s===$&&A.ab()
return s},
gp(){return this.Q},
gal(){return this.at},
sp(a){return this.Q=a}}
A.bK.prototype={
aU(a,b){var s
try{this.ag()}catch(s){this.aC()
throw s}},
ag(){var s,r,q=this,p=q.be()
try{if((q.r&8)!==0)return
r=q.a
if(r==null)return
s=r.$0()
if(t.Z.b(s))q.d=s}finally{p.$0()}},
be(){var s,r=this,q=r.r
if((q&1)!==0)throw A.h(new A.ay())
q|=1
r.r=q
r.r=q&4294967287
A.hc(r)
A.hm(r)
$.X=$.X+1
s=$.D
$.D=r
return new A.d_(r,s)},
ap(){var s=this,r=s.r
if((r&2)===0){s.r=r|2
s.f=$.eE
$.eE=s}},
aC(){var s,r,q,p=this
if(p.x)return
if(((p.r|=8)&1)===0)A.fm(p)
for(s=p.w,s=A.fY(s,s.r,s.$ti.c),r=s.$ti.c;s.k();){q=s.d;(q==null?r.a(q):q).$0()}p.x=!0},
gp(){return this.e},
gal(){return this.r},
sp(a){return this.e=a}}
A.d_.prototype={
$0(){var s=this.a
if($.D!==s)A.f4(A.fH("Out-of-order effect"))
A.hd(s)
$.D=this.b
if(((s.r&=4294967294)&8)!==0)A.fm(s)
A.fn()
return null},
$S:1}
A.aF.prototype={
aq(){for(var s=this.r;s!=null;s=s.f)s.d.ap()},
i(a){return A.o(this.gh())},
$0(){return this.gh()},
W(a){var s=this.r
if(s!==a&&a.e==null){a.f=s
if(s!=null)s.e=a
this.r=a}},
G(a){var s,r,q=this.r
if(q!=null){s=a.e
r=a.f
if(s!=null){s.f=r
a.e=null}if(r!=null){r.e=s
a.f=null}if(a===q)this.r=r}}}
A.ba.prototype={
a4(){return!0},
G(a){this.ac(a)},
aP(a){var s=this,r=s.Q
r===$&&A.ab()
r=s.as.$2(a,r)
if(r)return!1
if($.eM>100)throw A.h(new A.ay())
r=s.Q
r===$&&A.ab()
if(a==null?r!=null:a!==r){if(r==null)s.z===$&&A.ab()
s.Q=a}++s.e
$.eN=$.eN+1
$.X=$.X+1
try{s.aq()}finally{A.fn()}return!0},
sh(a){if(this.b)throw A.h(new A.cp("A "+A.hx(this).i(0)+" signal was written after being disposed.\nOnce you have called dispose() on a signal, it can no longer be used."))
this.aP(a)},
gh(){var s,r,q=this
if(q.b){A.hB("signal warning: ["+q.d+"|"+A.o(q.c)+"] has been read after disposed: "+A.ff().i(0))
s=q.Q
s===$&&A.ab()
return s}r=A.h8(q)
if(r!=null)r.r=q.e
s=q.Q
s===$&&A.ab()
return s}}
A.dZ.prototype={
$2(a,b){return a==null?b==null:a===b},
$S(){return this.a.j("v(0,0)")}}
A.es.prototype={}
A.co.prototype={
i(a){return this.a}}
A.cp.prototype={}
A.ay.prototype={};(function aliases(){var s=J.a2.prototype
s.aR=s.i
s=A.aF.prototype
s.aS=s.W
s.ac=s.G})();(function installTearOffs(){var s=hunkHelpers._static_0,r=hunkHelpers._static_1,q=hunkHelpers._instance_0u
s(A,"jv","ii",9)
r(A,"jK","iw",6)
r(A,"jL","ix",6)
r(A,"jM","iy",6)
s(A,"hs","jD",1)
q(A.bK.prototype,"gbk","aC",1)})();(function inheritance(){var s=hunkHelpers.mixin,r=hunkHelpers.inherit,q=hunkHelpers.inheritMany
r(A.j,null)
q(A.j,[A.fc,J.bS,A.b9,J.bE,A.p,A.dT,A.e,A.aC,A.c2,A.cw,A.aU,A.bm,A.Z,A.e5,A.dN,A.bL,A.bp,A.a4,A.dI,A.bY,A.bZ,A.bX,A.dG,A.J,A.cz,A.ez,A.bq,A.P,A.cA,A.K,A.cx,A.eC,A.cB,A.aG,A.er,A.aL,A.r,A.ax,A.cd,A.bb,A.eg,A.d4,A.ai,A.A,A.cD,A.e_,A.cs,A.at,A.m,A.cU,A.bn,A.aK,A.cH,A.cV,A.d1,A.d7,A.dd,A.dL,A.e0,A.C,A.dU,A.aF,A.bK,A.es])
q(J.bS,[J.bU,J.aZ,J.b1,J.b0,J.b2,J.b_,J.aA])
q(J.b1,[J.a2,J.t,A.aD,A.b6])
q(J.a2,[J.cf,J.bc,J.a1])
r(J.bT,A.b9)
r(J.dH,J.t)
q(J.b_,[J.aY,J.bV])
q(A.p,[A.b3,A.U,A.bW,A.cv,A.cl,A.cy,A.bF,A.O,A.bd,A.cu,A.cq,A.bJ,A.co,A.ay])
q(A.e,[A.i,A.S,A.W])
q(A.i,[A.R,A.ah,A.ag,A.bf])
r(A.ad,A.S)
r(A.T,A.R)
r(A.cC,A.bm)
r(A.a6,A.cC)
q(A.Z,[A.bH,A.bI,A.ct,A.eW,A.eY,A.ed,A.ec,A.eo,A.ew,A.f_,A.eI,A.eD,A.cK,A.cN,A.cO,A.cT,A.cL,A.cY,A.cW,A.d9,A.dq,A.dw,A.dx,A.dz,A.du,A.dt,A.dv,A.ds,A.dA,A.di,A.dj,A.dk,A.dm,A.dp,A.de,A.df,A.dM,A.f1,A.e2,A.e1,A.e3,A.dW,A.dV])
q(A.bH,[A.dP,A.ee,A.ef,A.ey,A.ex,A.d5,A.eh,A.ek,A.ej,A.ei,A.en,A.em,A.el,A.ev,A.eQ,A.eH,A.eG,A.eF,A.eL,A.eK,A.eJ,A.cI,A.cJ,A.cM,A.cP,A.cQ,A.cR,A.cS,A.cZ,A.cX,A.d8,A.dD,A.dC,A.dE,A.dB,A.dr,A.dy,A.dg,A.dh,A.dl,A.dn,A.f0,A.dY,A.dX,A.d_])
r(A.b8,A.U)
q(A.ct,[A.cr,A.au])
q(A.a4,[A.af,A.be])
q(A.bI,[A.eX,A.ep,A.dK,A.dZ])
q(A.b6,[A.c3,A.aE])
q(A.aE,[A.bi,A.bk])
r(A.bj,A.bi)
r(A.b4,A.bj)
r(A.bl,A.bk)
r(A.b5,A.bl)
q(A.b4,[A.c4,A.c5])
q(A.b5,[A.c6,A.c7,A.c8,A.c9,A.ca,A.b7,A.cb])
r(A.br,A.cy)
r(A.eu,A.eC)
r(A.bg,A.be)
r(A.bo,A.aG)
r(A.bh,A.bo)
r(A.cj,A.O)
q(A.m,[A.aT,A.aW,A.c0,A.aV,A.ck])
r(A.bN,A.aW)
r(A.x,A.c0)
r(A.a0,A.aV)
r(A.y,A.ck)
q(A.aT,[A.a_,A.aH,A.ce,A.bO,A.bP,A.az,A.av,A.bR,A.bD,A.bQ,A.bM,A.c1,A.cc,A.cm,A.cg])
q(A.aF,[A.aS,A.ba])
r(A.cp,A.co)
s(A.bi,A.r)
s(A.bj,A.aU)
s(A.bk,A.r)
s(A.bl,A.aU)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{c:"int",l:"double",hz:"num",f:"String",v:"bool",A:"Null",k:"List",j:"Object",a3:"Map",u:"JSObject"},mangledNames:{},types:["~(at)","~()","A()","aH()","m()","v()","~(~())","A(u)","A(@)","c()","y()","av()","v(f)","@(f)","@(@)","A(j,aI)","k<C>()","a_(C)","f(C)","~(j?,j?)","j?(j?)","@(@,f)","k<+done,id,text(v,f,f)>()","a_(+done,id,text(v,f,f))","+done,id,text(v,f,f)(+done,id,text(v,f,f))","v(+done,id,text(v,f,f))","f(+done,id,text(v,f,f))","az()","A(l)","~(u)","~(l)","~(e4)","C(c)","A(~())"],interceptorsByTag:null,leafTags:null,arrayRti:Symbol("$ti"),rttc:{"3;done,id,text":(a,b,c)=>d=>d instanceof A.a6&&a.b(d.a)&&b.b(d.b)&&c.b(d.c)}}
A.iQ(v.typeUniverse,JSON.parse('{"cf":"a2","bc":"a2","a1":"a2","k8":"aD","bU":{"v":[],"n":[]},"aZ":{"A":[],"n":[]},"b1":{"u":[]},"a2":{"u":[]},"t":{"k":["1"],"i":["1"],"u":[],"e":["1"]},"bT":{"b9":[]},"dH":{"t":["1"],"k":["1"],"i":["1"],"u":[],"e":["1"]},"b_":{"l":[]},"aY":{"l":[],"c":[],"n":[]},"bV":{"l":[],"n":[]},"aA":{"f":[],"n":[]},"b3":{"p":[]},"i":{"e":["1"]},"R":{"i":["1"],"e":["1"]},"S":{"e":["2"],"e.E":"2"},"ad":{"S":["1","2"],"i":["2"],"e":["2"],"e.E":"2"},"T":{"R":["2"],"i":["2"],"e":["2"],"e.E":"2","R.E":"2"},"W":{"e":["1"],"e.E":"1"},"b8":{"U":[],"p":[]},"bW":{"p":[]},"cv":{"p":[]},"bp":{"aI":[]},"Z":{"ae":[]},"bH":{"ae":[]},"bI":{"ae":[]},"ct":{"ae":[]},"cr":{"ae":[]},"au":{"ae":[]},"cl":{"p":[]},"af":{"a4":["1","2"],"a3":["1","2"]},"ah":{"i":["1"],"e":["1"],"e.E":"1"},"ag":{"i":["ai<1,2>"],"e":["ai<1,2>"],"e.E":"ai<1,2>"},"aD":{"u":[],"f7":[],"n":[]},"b6":{"u":[]},"c3":{"f8":[],"u":[],"n":[]},"aE":{"F":["1"],"u":[]},"b4":{"r":["l"],"k":["l"],"F":["l"],"i":["l"],"u":[],"e":["l"]},"b5":{"r":["c"],"k":["c"],"F":["c"],"i":["c"],"u":[],"e":["c"]},"c4":{"d2":[],"r":["l"],"k":["l"],"F":["l"],"i":["l"],"u":[],"e":["l"],"n":[],"r.E":"l"},"c5":{"d3":[],"r":["l"],"k":["l"],"F":["l"],"i":["l"],"u":[],"e":["l"],"n":[],"r.E":"l"},"c6":{"da":[],"r":["c"],"k":["c"],"F":["c"],"i":["c"],"u":[],"e":["c"],"n":[],"r.E":"c"},"c7":{"db":[],"r":["c"],"k":["c"],"F":["c"],"i":["c"],"u":[],"e":["c"],"n":[],"r.E":"c"},"c8":{"dc":[],"r":["c"],"k":["c"],"F":["c"],"i":["c"],"u":[],"e":["c"],"n":[],"r.E":"c"},"c9":{"e7":[],"r":["c"],"k":["c"],"F":["c"],"i":["c"],"u":[],"e":["c"],"n":[],"r.E":"c"},"ca":{"e8":[],"r":["c"],"k":["c"],"F":["c"],"i":["c"],"u":[],"e":["c"],"n":[],"r.E":"c"},"b7":{"e9":[],"r":["c"],"k":["c"],"F":["c"],"i":["c"],"u":[],"e":["c"],"n":[],"r.E":"c"},"cb":{"ea":[],"r":["c"],"k":["c"],"F":["c"],"i":["c"],"u":[],"e":["c"],"n":[],"r.E":"c"},"cy":{"p":[]},"br":{"U":[],"p":[]},"bq":{"e4":[]},"P":{"p":[]},"K":{"aX":["1"]},"be":{"a4":["1","2"],"a3":["1","2"]},"bg":{"be":["1","2"],"a4":["1","2"],"a3":["1","2"]},"bf":{"i":["1"],"e":["1"],"e.E":"1"},"bh":{"aG":["1"],"i":["1"],"e":["1"]},"a4":{"a3":["1","2"]},"aG":{"i":["1"],"e":["1"]},"bo":{"aG":["1"],"i":["1"],"e":["1"]},"k":{"i":["1"],"e":["1"]},"bF":{"p":[]},"U":{"p":[]},"O":{"p":[]},"cj":{"p":[]},"bd":{"p":[]},"cu":{"p":[]},"cq":{"p":[]},"bJ":{"p":[]},"cd":{"p":[]},"bb":{"p":[]},"cD":{"aI":[]},"y":{"m":[]},"a_":{"m":[]},"aH":{"m":[]},"az":{"m":[]},"av":{"m":[]},"aT":{"m":[]},"aW":{"m":[]},"c0":{"m":[]},"aV":{"m":[]},"ck":{"m":[]},"bN":{"m":[]},"x":{"m":[]},"a0":{"aV":["1"],"m":[]},"ce":{"m":[]},"bO":{"m":[]},"bP":{"m":[]},"bR":{"m":[]},"bD":{"m":[]},"bQ":{"m":[]},"bM":{"m":[]},"c1":{"m":[]},"cc":{"m":[]},"cm":{"m":[]},"cg":{"m":[]},"aS":{"aF":["1"]},"ba":{"aF":["1"]},"co":{"p":[]},"cp":{"p":[]},"ay":{"p":[]},"dc":{"k":["c"],"i":["c"],"e":["c"]},"ea":{"k":["c"],"i":["c"],"e":["c"]},"e9":{"k":["c"],"i":["c"],"e":["c"]},"da":{"k":["c"],"i":["c"],"e":["c"]},"e7":{"k":["c"],"i":["c"],"e":["c"]},"db":{"k":["c"],"i":["c"],"e":["c"]},"e8":{"k":["c"],"i":["c"],"e":["c"]},"d2":{"k":["l"],"i":["l"],"e":["l"]},"d3":{"k":["l"],"i":["l"],"e":["l"]}}'))
A.iP(v.typeUniverse,JSON.parse('{"i":1,"cw":1,"aU":1,"bY":1,"bZ":1,"aE":1,"bo":1}'))
var u={c:"Error handler must accept one Object or one Object and a StackTrace as arguments, and return a value of the returned future's type",d:"text-3xl sm:text-4xl font-bold text-white mt-2 mb-4",a:"text-xs font-mono text-indigo-400 font-semibold uppercase tracking-wider"}
var t=(function rtii(){var s=A.eT
return{W:s("C"),c:s("m"),J:s("f7"),Y:s("f8"),a:s("i<@>"),Q:s("p"),B:s("d2"),q:s("d3"),R:s("a0<C>"),d:s("a0<+done,id,text(v,f,f)>"),Z:s("ae"),e:s("da"),k:s("db"),U:s("dc"),f:s("e<@>"),t:s("t<m>"),O:s("t<u>"),x:s("t<a3<f,j>>"),h:s("t<+done,id,text(v,f,f)>"),s:s("t<f>"),r:s("t<aK>"),n:s("t<l>"),b:s("t<@>"),T:s("aZ"),m:s("u"),g:s("a1"),p:s("F<@>"),w:s("k<C>"),D:s("k<j>"),E:s("k<+done,id,text(v,f,f)>"),j:s("k<@>"),G:s("a3<f,j>"),cy:s("a3<f,a3<f,j>>"),P:s("A"),K:s("j"),L:s("k9"),F:s("+()"),V:s("+done,id,text(v,f,f)"),l:s("aI"),N:s("f"),ae:s("e4"),bW:s("n"),_:s("U"),c0:s("e7"),bk:s("e8"),ca:s("e9"),bX:s("ea"),o:s("bc"),A:s("bg<j?,j?>"),cl:s("aK"),y:s("v"),i:s("l"),z:s("@"),v:s("@(j)"),C:s("@(j,aI)"),S:s("c"),bc:s("aX<A>?"),aQ:s("u?"),X:s("j?"),u:s("f?"),cG:s("v?"),I:s("l?"),a3:s("c?"),be:s("hz?"),H:s("hz"),b9:s("~"),M:s("~()"),co:s("~(at)")}})();(function constants(){var s=hunkHelpers.makeConstList
B.z=J.bS.prototype
B.h=J.t.prototype
B.b=J.aY.prototype
B.e=J.b_.prototype
B.d=J.aA.prototype
B.A=J.a1.prototype
B.B=J.b1.prototype
B.n=J.cf.prototype
B.i=J.bc.prototype
B.j=function getTagFallback(o) {
  var s = Object.prototype.toString.call(o);
  return s.substring(8, s.length - 1);
}
B.o=function() {
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
B.u=function(getTagFallback) {
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
B.p=function(hooks) {
  if (typeof dartExperimentalFixupGetTag != "function") return hooks;
  hooks.getTag = dartExperimentalFixupGetTag(hooks.getTag);
}
B.t=function(hooks) {
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
B.r=function(hooks) {
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
B.q=function(hooks) {
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
B.k=function(hooks) { return hooks; }

B.v=new A.cd()
B.l=new A.dT()
B.c=new A.eu()
B.w=new A.cD()
B.x=new A.ax(0)
B.m=new A.ax(3e6)
B.y=new A.ax(32e3)
B.a=s([],t.t)
B.f=new A.bN(B.a)
B.C=A.L("f7")
B.D=A.L("f8")
B.E=A.L("d2")
B.F=A.L("d3")
B.G=A.L("da")
B.H=A.L("db")
B.I=A.L("dc")
B.J=A.L("j")
B.K=A.L("e7")
B.L=A.L("e8")
B.M=A.L("e9")
B.N=A.L("ea")})();(function staticFields(){$.eq=null
$.am=A.b([],A.eT("t<j>"))
$.fO=null
$.dQ=0
$.dR=A.jv()
$.fE=null
$.fD=null
$.hy=null
$.hr=null
$.hC=null
$.eS=null
$.eZ=null
$.fu=null
$.et=A.b([],A.eT("t<k<j>?>"))
$.aN=null
$.bx=null
$.bz=null
$.fp=!1
$.w=B.c
$.eN=0
$.D=null
$.eE=null
$.X=0
$.eM=0
$.by=0})();(function lazyInitializers(){var s=hunkHelpers.lazyFinal
s($,"k7","hF",()=>A.eV("_$dart_dartClosure"))
s($,"k6","fx",()=>A.eV("_$dart_dartClosure_dartJSInterop"))
s($,"ko","hR",()=>A.b([new J.bT()],A.eT("t<b9>")))
s($,"kc","hH",()=>A.V(A.e6({
toString:function(){return"$receiver$"}})))
s($,"kd","hI",()=>A.V(A.e6({$method$:null,
toString:function(){return"$receiver$"}})))
s($,"ke","hJ",()=>A.V(A.e6(null)))
s($,"kf","hK",()=>A.V(function(){var $argumentsExpr$="$arguments$"
try{null.$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"ki","hN",()=>A.V(A.e6(void 0)))
s($,"kj","hO",()=>A.V(function(){var $argumentsExpr$="$arguments$"
try{(void 0).$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"kh","hM",()=>A.V(A.fT(null)))
s($,"kg","hL",()=>A.V(function(){try{null.$method$}catch(r){return r.message}}()))
s($,"kl","hQ",()=>A.V(A.fT(void 0)))
s($,"kk","hP",()=>A.V(function(){try{(void 0).$method$}catch(r){return r.message}}()))
s($,"km","fz",()=>A.iv())
s($,"kn","f5",()=>A.f3(B.J))
s($,"kb","fy",()=>{A.ik()
return $.dQ})
s($,"ka","hG",()=>A.iq())})();(function nativeSupport(){!function(){var s=function(a){var m={}
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
hunkHelpers.setOrUpdateInterceptorsByTag({ArrayBuffer:A.aD,SharedArrayBuffer:A.aD,ArrayBufferView:A.b6,DataView:A.c3,Float32Array:A.c4,Float64Array:A.c5,Int16Array:A.c6,Int32Array:A.c7,Int8Array:A.c8,Uint16Array:A.c9,Uint32Array:A.ca,Uint8ClampedArray:A.b7,CanvasPixelArray:A.b7,Uint8Array:A.cb})
hunkHelpers.setOrUpdateLeafTags({ArrayBuffer:true,SharedArrayBuffer:true,ArrayBufferView:false,DataView:true,Float32Array:true,Float64Array:true,Int16Array:true,Int32Array:true,Int8Array:true,Uint16Array:true,Uint32Array:true,Uint8ClampedArray:true,CanvasPixelArray:true,Uint8Array:false})
A.aE.$nativeSuperclassTag="ArrayBufferView"
A.bi.$nativeSuperclassTag="ArrayBufferView"
A.bj.$nativeSuperclassTag="ArrayBufferView"
A.b4.$nativeSuperclassTag="ArrayBufferView"
A.bk.$nativeSuperclassTag="ArrayBufferView"
A.bl.$nativeSuperclassTag="ArrayBufferView"
A.b5.$nativeSuperclassTag="ArrayBufferView"})()
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
var s=A.jZ
if(typeof dartMainRunner==="function"){dartMainRunner(s,[])}else{s([])}})})()
//# sourceMappingURL=main.js.map
