(function dartProgram(){function copyProperties(a,b){var t=Object.keys(a)
for(var s=0;s<t.length;s++){var r=t[s]
b[r]=a[r]}}function mixinPropertiesHard(a,b){var t=Object.keys(a)
for(var s=0;s<t.length;s++){var r=t[s]
if(!b.hasOwnProperty(r)){b[r]=a[r]}}}function mixinPropertiesEasy(a,b){Object.assign(b,a)}var z=function(){var t=function(){}
t.prototype={p:{}}
var s=new t()
if(!(Object.getPrototypeOf(s)&&Object.getPrototypeOf(s).p===t.prototype.p))return false
try{if(typeof navigator!="undefined"&&typeof navigator.userAgent=="string"&&navigator.userAgent.indexOf("Chrome/")>=0)return true
if(typeof version=="function"&&version.length==0){var r=version()
if(/^\d+\.\d+\.\d+\.\d+$/.test(r))return true}}catch(q){}return false}()
function inherit(a,b){a.prototype.constructor=a
a.prototype["$i"+a.name]=a
if(b!=null){if(z){Object.setPrototypeOf(a.prototype,b.prototype)
return}var t=Object.create(b.prototype)
copyProperties(a.prototype,t)
a.prototype=t}}function inheritMany(a,b){for(var t=0;t<b.length;t++){inherit(b[t],a)}}function mixinEasy(a,b){mixinPropertiesEasy(b.prototype,a.prototype)
a.prototype.constructor=a}function mixinHard(a,b){mixinPropertiesHard(b.prototype,a.prototype)
a.prototype.constructor=a}function lazy(a,b,c,d){var t=a
a[b]=t
a[c]=function(){if(a[b]===t){a[b]=d()}a[c]=function(){return this[b]}
return a[b]}}function lazyFinal(a,b,c,d){var t=a
a[b]=t
a[c]=function(){if(a[b]===t){var s=d()
if(a[b]!==t){A.hj(b)}a[b]=s}var r=a[b]
a[c]=function(){return r}
return r}}function makeConstList(a,b){if(b!=null)A.d(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var t=0;t<a.length;++t){convertToFastObject(a[t])}}var y=0
function instanceTearOffGetter(a,b){var t=null
return a?function(c){if(t===null)t=A.dk(b)
return new t(c,this)}:function(){if(t===null)t=A.dk(b)
return new t(this,null)}}function staticTearOffGetter(a){var t=null
return function(){if(t===null)t=A.dk(a).prototype
return t}}var x=0
function tearOffParameters(a,b,c,d,e,f,g,h,i,j){if(typeof h=="number"){h+=x}return{co:a,iS:b,iI:c,rC:d,dV:e,cs:f,fs:g,fT:h,aI:i||0,nDA:j}}function installStaticTearOff(a,b,c,d,e,f,g,h){var t=tearOffParameters(a,true,false,c,d,e,f,g,h,false)
var s=staticTearOffGetter(t)
a[b]=s}function installInstanceTearOff(a,b,c,d,e,f,g,h,i,j){c=!!c
var t=tearOffParameters(a,false,c,d,e,f,g,h,i,!!j)
var s=instanceTearOffGetter(c,t)
a[b]=s}function setOrUpdateInterceptorsByTag(a){var t=v.interceptorsByTag
if(!t){v.interceptorsByTag=a
return}copyProperties(a,t)}function setOrUpdateLeafTags(a){var t=v.leafTags
if(!t){v.leafTags=a
return}copyProperties(a,t)}function updateTypes(a){var t=v.types
var s=t.length
t.push.apply(t,a)
return s}function updateHolder(a,b){copyProperties(b,a)
return a}var hunkHelpers=function(){var t=function(a,b,c,d,e){return function(f,g,h,i){return installInstanceTearOff(f,g,a,b,c,d,[h],i,e,false)}},s=function(a,b,c,d){return function(e,f,g,h){return installStaticTearOff(e,f,a,b,c,[g],h,d)}}
return{inherit:inherit,inheritMany:inheritMany,mixin:mixinEasy,mixinHard:mixinHard,installStaticTearOff:installStaticTearOff,installInstanceTearOff:installInstanceTearOff,_instance_0u:t(0,0,null,["$0"],0),_instance_1u:t(0,1,null,["$1"],0),_instance_2u:t(0,2,null,["$2"],0),_instance_0i:t(1,0,null,["$0"],0),_instance_1i:t(1,1,null,["$1"],0),_instance_2i:t(1,2,null,["$2"],0),_static_0:s(0,null,["$0"],0),_static_1:s(1,null,["$1"],0),_static_2:s(2,null,["$2"],0),makeConstList:makeConstList,lazy:lazy,lazyFinal:lazyFinal,updateHolder:updateHolder,convertToFastObject:convertToFastObject,updateTypes:updateTypes,setOrUpdateInterceptorsByTag:setOrUpdateInterceptorsByTag,setOrUpdateLeafTags:setOrUpdateLeafTags}}()
function initializeDeferredHunk(a){x=v.types.length
a(hunkHelpers,v,w,$)}var J={
dr(a,b,c,d){return{i:a,p:b,e:c,x:d}},
dn(a){var t,s,r,q,p,o="_$dart_js",n=a[v.dispatchPropertyName]
if(n==null)if($.dp==null){A.h8()
n=a[v.dispatchPropertyName]}if(n!=null){t=n.p
if(!1===t)return n.i
if(!0===t)return a
s=Object.getPrototypeOf(a)
if(t===s)return n.i
if(n.e===s)throw A.i(A.dK("Return interceptor for "+A.n(t(a,n))))}r=a.constructor
if(r==null)q=null
else{p=$.ci
if(p==null)p=$.ci=A.cC(o)
q=r[p]}if(q!=null)return q
q=A.hc(a)
if(q!=null)return q
if(typeof a=="function")return B.r
t=Object.getPrototypeOf(a)
if(t==null)return B.f
if(t===Object.prototype)return B.f
if(typeof r=="function"){p=$.ci
if(p==null)p=$.ci=A.cC(o)
Object.defineProperty(r,p,{value:B.b,enumerable:false,writable:true,configurable:true})
return B.b}return B.b},
dB(a){if(a<256)switch(a){case 9:case 10:case 11:case 12:case 13:case 32:case 133:case 160:return!0
default:return!1}switch(a){case 5760:case 8192:case 8193:case 8194:case 8195:case 8196:case 8197:case 8198:case 8199:case 8200:case 8201:case 8202:case 8232:case 8233:case 8239:case 8287:case 12288:case 65279:return!0
default:return!1}},
eQ(a,b){var t,s
for(t=a.length;b<t;){s=a.charCodeAt(b)
if(s!==32&&s!==13&&!J.dB(s))break;++b}return b},
eR(a,b){var t,s
for(;b>0;b=t){t=b-1
s=a.charCodeAt(t)
if(s!==32&&s!==13&&!J.dB(s))break}return b},
a_(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.ax.prototype
return J.bl.prototype}if(typeof a=="string")return J.a7.prototype
if(a==null)return J.ay.prototype
if(typeof a=="boolean")return J.bk.prototype
if(Array.isArray(a))return J.m.prototype
if(typeof a!="object"){if(typeof a=="function")return J.I.prototype
if(typeof a=="symbol")return J.aB.prototype
if(typeof a=="bigint")return J.az.prototype
return a}if(a instanceof A.k)return a
return J.dn(a)},
ec(a){if(typeof a=="string")return J.a7.prototype
if(a==null)return a
if(Array.isArray(a))return J.m.prototype
if(typeof a!="object"){if(typeof a=="function")return J.I.prototype
if(typeof a=="symbol")return J.aB.prototype
if(typeof a=="bigint")return J.az.prototype
return a}if(a instanceof A.k)return a
return J.dn(a)},
dm(a){if(a==null)return a
if(Array.isArray(a))return J.m.prototype
if(typeof a!="object"){if(typeof a=="function")return J.I.prototype
if(typeof a=="symbol")return J.aB.prototype
if(typeof a=="bigint")return J.az.prototype
return a}if(a instanceof A.k)return a
return J.dn(a)},
d6(a,b){if(a==null)return b==null
if(typeof a!="object")return b!=null&&a===b
return J.a_(a).C(a,b)},
ey(a,b){return J.dm(a).F(a,b)},
c1(a){return J.a_(a).gp(a)},
c2(a){return J.dm(a).gq(a)},
ez(a){return J.ec(a).gu(a)},
eA(a){return J.a_(a).gm(a)},
eB(a,b,c){return J.dm(a).Y(a,b,c)},
b1(a){return J.a_(a).h(a)},
bi:function bi(){},
bk:function bk(){},
ay:function ay(){},
aA:function aA(){},
J:function J(){},
bC:function bC(){},
aP:function aP(){},
I:function I(){},
az:function az(){},
aB:function aB(){},
m:function m(a){this.$ti=a},
bj:function bj(){},
c7:function c7(a){this.$ti=a},
b2:function b2(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
bm:function bm(){},
ax:function ax(){},
bl:function bl(){},
a7:function a7(){}},A={d8:function d8(){},
eS(a){return new A.aC("Field '"+a+"' has not been initialized.")},
dq(a){var t,s
for(t=$.Y.length,s=0;s<t;++s)if(a===$.Y[s])return!0
return!1},
aC:function aC(a){this.a=a},
at:function at(){},
K:function K(){},
a9:function a9(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
S:function S(a,b,c){this.a=a
this.b=b
this.$ti=c},
A:function A(a,b,c){this.a=a
this.b=b
this.$ti=c},
bT:function bT(a,b){this.a=a
this.b=b},
av:function av(){},
ek(a){var t=A.ej(a)
if(t!=null)return t
return"minified:"+a},
hE(a,b){var t
if(b!=null){t=b.x
if(t!=null)return t}return u.p.b(a)},
n(a){var t
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
t=J.b1(a)
return t},
bD(a){var t,s=$.dD
if(s==null)s=$.dD=Symbol("identityHashCode")
t=a[s]
if(t==null){t=Math.random()*0x3fffffff|0
a[s]=t}return t},
bE(a){var t,s,r,q
if(a instanceof A.k)return A.w(A.al(a),null)
t=J.a_(a)
if(t===B.o||t===B.t||u.A.b(a)){s=B.c(a)
if(s!=="Object"&&s!=="")return s
r=a.constructor
if(typeof r=="function"){q=r.name
if(typeof q=="string"&&q!=="Object"&&q!=="")return q}}return A.w(A.al(a),null)},
eV(a){var t,s,r
if(typeof a=="number"||A.dj(a))return J.b1(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.G)return a.h(0)
t=$.ex()
for(s=0;s<1;++s){r=t[s].ap(a)
if(r!=null)return r}return"Instance of '"+A.bE(a)+"'"},
i(a){return A.q(a,new Error())},
q(a,b){var t
if(a==null)a=new A.aO()
b.dartException=a
t=A.hl
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:t})
b.name=""}else b.toString=t
return b},
hl(){return J.b1(this.dartException)},
c0(a,b){throw A.q(a,b==null?new Error():b)},
hk(a,b,c){var t
if(b==null)b=0
if(c==null)c=0
t=Error()
A.c0(A.fx(a,b,c),t)},
fx(a,b,c){var t,s,r,q,p,o,n,m,l
if(typeof b=="string")t=b
else{s="[]=;add;removeWhere;retainWhere;removeRange;setRange;setInt8;setInt16;setInt32;setUint8;setUint16;setUint32;setFloat32;setFloat64".split(";")
r=s.length
q=b
if(q>r){c=q/r|0
q%=r}t=s[q]}p=typeof c=="string"?c:"modify;remove from;add to".split(";")[c]
o=u.j.b(a)?"list":"ByteData"
n=a.$flags|0
m="a "
if((n&4)!==0)l="constant "
else if((n&2)!==0){l="unmodifiable "
m="an "}else l=(n&1)!==0?"fixed-length ":""
return new A.bS("'"+t+"': Cannot "+p+" "+m+l+o)},
an(a){throw A.i(A.ar(a))},
E(a){var t,s,r,q,p,o
a=A.hi(a.replace(String({}),"$receiver$"))
t=a.match(/\\\$[a-zA-Z]+\\\$/g)
if(t==null)t=A.d([],u.s)
s=t.indexOf("\\$arguments\\$")
r=t.indexOf("\\$argumentsExpr\\$")
q=t.indexOf("\\$expr\\$")
p=t.indexOf("\\$method\\$")
o=t.indexOf("\\$receiver\\$")
return new A.ce(a.replace(new RegExp("\\\\\\$arguments\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$argumentsExpr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$expr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$method\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$receiver\\\\\\$","g"),"((?:x|[^x])*)"),s,r,q,p,o)},
cf(a){return function($expr$){var $argumentsExpr$="$arguments$"
try{$expr$.$method$($argumentsExpr$)}catch(t){return t.message}}(a)},
dJ(a){return function($expr$){try{$expr$.$method$}catch(t){return t.message}}(a)},
d9(a,b){var t=b==null,s=t?null:b.method
return new A.bn(a,s,t?null:b.receiver)},
el(a){if(a==null)return new A.cb(a)
if(a instanceof A.bb)return A.P(a,a.a)
if(typeof a!=="object")return a
if("dartException" in a)return A.P(a,a.dartException)
return A.h0(a)},
P(a,b){if(u.C.b(b))if(b.$thrownJsError==null)b.$thrownJsError=a
return b},
h0(a){var t,s,r,q,p,o,n,m,l,k,j,i,h
if(!("message" in a))return a
t=a.message
if("number" in a&&typeof a.number=="number"){s=a.number
r=s&65535
if((B.e.ac(s,16)&8191)===10)switch(r){case 438:return A.P(a,A.d9(A.n(t)+" (Error "+r+")",null))
case 445:case 5007:A.n(t)
return A.P(a,new A.aI())}}if(a instanceof TypeError){q=$.en()
p=$.eo()
o=$.ep()
n=$.eq()
m=$.et()
l=$.eu()
k=$.es()
$.er()
j=$.ew()
i=$.ev()
h=q.t(t)
if(h!=null)return A.P(a,A.d9(t,h))
else{h=p.t(t)
if(h!=null){h.method="call"
return A.P(a,A.d9(t,h))}else if(o.t(t)!=null||n.t(t)!=null||m.t(t)!=null||l.t(t)!=null||k.t(t)!=null||n.t(t)!=null||j.t(t)!=null||i.t(t)!=null)return A.P(a,new A.aI())}return A.P(a,new A.bR(typeof t=="string"?t:""))}if(a instanceof RangeError){if(typeof t=="string"&&t.indexOf("call stack")!==-1)return new A.aN()
t=function(b){try{return String(b)}catch(g){}return null}(a)
return A.P(a,new A.ao(!1,null,null,typeof t=="string"?t.replace(/^RangeError:\s*/,""):t))}if(typeof InternalError=="function"&&a instanceof InternalError)if(typeof t=="string"&&t==="too much recursion")return new A.aN()
return a},
h5(a){var t
if(a instanceof A.bb)return a.b
if(a==null)return new A.bY(a)
t=a.$cachedTrace
if(t!=null)return t
t=new A.bY(a)
if(typeof a==="object")a.$cachedTrace=t
return t},
hg(a){if(a==null)return J.c1(a)
if(typeof a=="object")return A.bD(a)
return J.c1(a)},
h4(a,b){var t,s,r,q=a.length
for(t=0;t<q;t=r){s=t+1
r=s+1
b.v(0,a[t],a[s])}return b},
eI(a1){var t,s,r,q,p,o,n,m,l,k,j=a1.co,i=a1.iS,h=a1.iI,g=a1.nDA,f=a1.aI,e=a1.fs,d=a1.cs,c=e[0],b=d[0],a=j[c],a0=a1.fT
a0.toString
t=i?Object.create(new A.bL().constructor.prototype):Object.create(new A.a3(null,null).constructor.prototype)
t.$initialize=t.constructor
s=i?function static_tear_off(){this.$initialize()}:function tear_off(a2,a3){this.$initialize(a2,a3)}
t.constructor=s
s.prototype=t
t.$_name=c
t.$_target=a
r=!i
if(r)q=A.dy(c,a,h,g)
else{t.$static_name=c
q=a}t.$S=A.eE(a0,i,h)
t[b]=q
for(p=q,o=1;o<e.length;++o){n=e[o]
if(typeof n=="string"){m=j[n]
l=n
n=m}else l=""
k=d[o]
if(k!=null){if(r)n=A.dy(l,n,h,g)
t[k]=n}if(o===f)p=n}t.$C=p
t.$R=a1.rC
t.$D=a1.dV
return s},
eE(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.i("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.eC)}throw A.i("Error in functionType of tearoff")},
eF(a,b,c,d){var t=A.dx
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,t)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,t)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,t)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,t)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,t)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,t)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,t)}},
dy(a,b,c,d){if(c)return A.eH(a,b,d)
return A.eF(b.length,d,a,b)},
eG(a,b,c,d){var t=A.dx,s=A.eD
switch(b?-1:a){case 0:throw A.i(new A.bF("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,s,t)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,s,t)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,s,t)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,s,t)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,s,t)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,s,t)
default:return function(e,f,g){return function(){var r=[g(this)]
Array.prototype.push.apply(r,arguments)
return e.apply(f(this),r)}}(d,s,t)}},
eH(a,b,c){var t,s
if($.dv==null)$.dv=A.du("interceptor")
if($.dw==null)$.dw=A.du("receiver")
t=b.length
s=A.eG(t,c,a,b)
return s},
dk(a){return A.eI(a)},
eC(a,b){return A.cn(v.typeUniverse,A.al(a.a),b)},
dx(a){return a.a},
eD(a){return a.b},
du(a){var t,s,r,q=new A.a3("receiver","interceptor"),p=Object.getOwnPropertyNames(q)
p.$flags=1
t=p
for(p=t.length,s=0;s<p;++s){r=t[s]
if(q[r]===a)return r}throw A.i(A.dt("Field name "+a+" not found.",null))},
cC(a){return v.getIsolateTag(a)},
hc(a){var t,s,r,q,p,o=$.ee.$1(a),n=$.cB[o]
if(n!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}t=$.cG[o]
if(t!=null)return t
s=v.interceptorsByTag[o]
if(s==null){r=$.ea.$2(a,o)
if(r!=null){n=$.cB[r]
if(n!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}t=$.cG[r]
if(t!=null)return t
s=v.interceptorsByTag[r]
o=r}}if(s==null)return null
t=s.prototype
q=o[0]
if(q==="!"){n=A.d4(t)
$.cB[o]=n
Object.defineProperty(a,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
return n.i}if(q==="~"){$.cG[o]=t
return t}if(q==="-"){p=A.d4(t)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:p,enumerable:false,writable:true,configurable:true})
return p.i}if(q==="+")return A.eg(a,t)
if(q==="*")throw A.i(A.dK(o))
if(v.leafTags[o]===true){p=A.d4(t)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:p,enumerable:false,writable:true,configurable:true})
return p.i}else return A.eg(a,t)},
eg(a,b){var t=Object.getPrototypeOf(a)
Object.defineProperty(t,v.dispatchPropertyName,{value:J.dr(b,t,null,null),enumerable:false,writable:true,configurable:true})
return b},
d4(a){return J.dr(a,!1,null,!!a.$iv)},
he(a,b,c){var t=b.prototype
if(v.leafTags[a]===true)return A.d4(t)
else return J.dr(t,c,null,null)},
h8(){if(!0===$.dp)return
$.dp=!0
A.h9()},
h9(){var t,s,r,q,p,o,n,m
$.cB=Object.create(null)
$.cG=Object.create(null)
A.h7()
t=v.interceptorsByTag
s=Object.getOwnPropertyNames(t)
if(typeof window!="undefined"){window
r=function(){}
for(q=0;q<s.length;++q){p=s[q]
o=$.ei.$1(p)
if(o!=null){n=A.he(p,t[p],o)
if(n!=null){Object.defineProperty(o,v.dispatchPropertyName,{value:n,enumerable:false,writable:true,configurable:true})
r.prototype=o}}}}for(q=0;q<s.length;++q){p=s[q]
if(/^[A-Za-z_]/.test(p)){m=t[p]
t["!"+p]=m
t["~"+p]=m
t["-"+p]=m
t["+"+p]=m
t["*"+p]=m}}},
h7(){var t,s,r,q,p,o,n=B.i()
n=A.aj(B.j,A.aj(B.k,A.aj(B.d,A.aj(B.d,A.aj(B.l,A.aj(B.m,A.aj(B.n(B.c),n)))))))
if(typeof dartNativeDispatchHooksTransformer!="undefined"){t=dartNativeDispatchHooksTransformer
if(typeof t=="function")t=[t]
if(Array.isArray(t))for(s=0;s<t.length;++s){r=t[s]
if(typeof r=="function")n=r(n)||n}}q=n.getTag
p=n.getUnknownTag
o=n.prototypeForTag
$.ee=new A.cD(q)
$.ea=new A.cE(p)
$.ei=new A.cF(o)},
aj(a,b){return a(b)||b},
h2(a,b){var t=b.length,s=v.rttc[""+t+";"+a]
if(s==null)return null
if(t===0)return s
if(t===s.length)return s.apply(null,b)
return s(b)},
hi(a){if(/[[\]{}()*+?.\\^$|]/.test(a))return a.replace(/[[\]{}()*+?.\\^$|]/g,"\\$&")
return a},
b8:function b8(){},
as:function as(a,b,c){this.a=a
this.b=b
this.$ti=c},
aQ:function aQ(a,b){this.a=a
this.$ti=b},
bW:function bW(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
aJ:function aJ(){},
ce:function ce(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
aI:function aI(){},
bn:function bn(a,b,c){this.a=a
this.b=b
this.c=c},
bR:function bR(a){this.a=a},
cb:function cb(a){this.a=a},
bb:function bb(){},
bY:function bY(a){this.a=a
this.b=null},
G:function G(){},
b5:function b5(){},
b6:function b6(){},
bN:function bN(){},
bL:function bL(){},
a3:function a3(a,b){this.a=a
this.b=b},
bF:function bF(a){this.a=a},
C:function C(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
c8:function c8(a){this.a=a},
c9:function c9(a,b){var _=this
_.a=a
_.b=b
_.d=_.c=null},
R:function R(a,b){this.a=a
this.$ti=b},
bo:function bo(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
cD:function cD(a){this.a=a},
cE:function cE(a){this.a=a},
cF:function cF(a){this.a=a},
aa:function aa(){},
aG:function aG(){},
bs:function bs(){},
ab:function ab(){},
aE:function aE(){},
aF:function aF(){},
bt:function bt(){},
bu:function bu(){},
bv:function bv(){},
bw:function bw(){},
bx:function bx(){},
by:function by(){},
bz:function bz(){},
aH:function aH(){},
bA:function bA(){},
aS:function aS(){},
aT:function aT(){},
aU:function aU(){},
aV:function aV(){},
db(a,b){var t=b.c
return t==null?b.c=A.aZ(a,"dz",[b.x]):t},
dE(a){var t=a.w
if(t===6||t===7)return A.dE(a.x)
return t===11||t===12},
eW(a){return a.as},
c_(a){return A.cm(v.typeUniverse,a,!1)},
X(a0,a1,a2,a3){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a=a1.w
switch(a){case 5:case 1:case 2:case 3:case 4:return a1
case 6:t=a1.x
s=A.X(a0,t,a2,a3)
if(s===t)return a1
return A.dT(a0,s,!0)
case 7:t=a1.x
s=A.X(a0,t,a2,a3)
if(s===t)return a1
return A.dS(a0,s,!0)
case 8:r=a1.y
q=A.ai(a0,r,a2,a3)
if(q===r)return a1
return A.aZ(a0,a1.x,q)
case 9:p=a1.x
o=A.X(a0,p,a2,a3)
n=a1.y
m=A.ai(a0,n,a2,a3)
if(o===p&&m===n)return a1
return A.dd(a0,o,m)
case 10:l=a1.x
k=a1.y
j=A.ai(a0,k,a2,a3)
if(j===k)return a1
return A.dU(a0,l,j)
case 11:i=a1.x
h=A.X(a0,i,a2,a3)
g=a1.y
f=A.fY(a0,g,a2,a3)
if(h===i&&f===g)return a1
return A.dR(a0,h,f)
case 12:e=a1.y
a3+=e.length
d=A.ai(a0,e,a2,a3)
p=a1.x
o=A.X(a0,p,a2,a3)
if(d===e&&o===p)return a1
return A.de(a0,o,d,!0)
case 13:c=a1.x
if(c<a3)return a1
b=a2[c-a3]
if(b==null)return a1
return b
default:throw A.i(A.b4("Attempted to substitute unexpected RTI kind "+a))}},
ai(a,b,c,d){var t,s,r,q,p=b.length,o=A.co(p)
for(t=!1,s=0;s<p;++s){r=b[s]
q=A.X(a,r,c,d)
if(q!==r)t=!0
o[s]=q}return t?o:b},
fZ(a,b,c,d){var t,s,r,q,p,o,n=b.length,m=A.co(n)
for(t=!1,s=0;s<n;s+=3){r=b[s]
q=b[s+1]
p=b[s+2]
o=A.X(a,p,c,d)
if(o!==p)t=!0
m.splice(s,3,r,q,o)}return t?m:b},
fY(a,b,c,d){var t,s=b.a,r=A.ai(a,s,c,d),q=b.b,p=A.ai(a,q,c,d),o=b.c,n=A.fZ(a,o,c,d)
if(r===s&&p===q&&n===o)return b
t=new A.bV()
t.a=r
t.b=p
t.c=n
return t},
d(a,b){a[v.arrayRti]=b
return a},
eb(a){var t=a.$S
if(t!=null){if(typeof t=="number")return A.h6(t)
return a.$S()}return null},
ha(a,b){var t
if(A.dE(b))if(a instanceof A.G){t=A.eb(a)
if(t!=null)return t}return A.al(a)},
al(a){if(a instanceof A.k)return A.ah(a)
if(Array.isArray(a))return A.W(a)
return A.di(J.a_(a))},
W(a){var t=a[v.arrayRti],s=u.b
if(t==null)return s
if(t.constructor!==s.constructor)return s
return t},
ah(a){var t=a.$ti
return t!=null?t:A.di(a)},
di(a){var t=a.constructor,s=t.$ccache
if(s!=null)return s
return A.fE(a,t)},
fE(a,b){var t=a instanceof A.G?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,s=A.fh(v.typeUniverse,t.name)
b.$ccache=s
return s},
h6(a){var t,s=v.types,r=s[a]
if(typeof r=="string"){t=A.cm(v.typeUniverse,r,!1)
s[a]=t
return t}return r},
ed(a){return A.Z(A.ah(a))},
fX(a){var t=a instanceof A.G?A.eb(a):null
if(t!=null)return t
if(u.R.b(a))return J.eA(a).a
if(Array.isArray(a))return A.W(a)
return A.al(a)},
Z(a){var t=a.r
return t==null?a.r=new A.cl(a):t},
B(a){return A.Z(A.cm(v.typeUniverse,a,!1))},
fD(a){var t=this
t.b=A.fW(t)
return t.b(a)},
fW(a){var t,s,r,q
if(a===u.K)return A.fL
if(A.a0(a))return A.fP
t=a.w
if(t===6)return A.fB
if(t===1)return A.e6
if(t===7)return A.fF
s=A.fV(a)
if(s!=null)return s
if(t===8){r=a.x
if(a.y.every(A.a0)){a.f="$i"+r
if(r==="c")return A.fJ
if(a===u.m)return A.fI
return A.fO}}else if(t===10){q=A.h2(a.x,a.y)
return q==null?A.e6:q}return A.fz},
fV(a){if(a.w===8){if(a===u.S)return A.fG
if(a===u.i||a===u.H)return A.fK
if(a===u.N)return A.fN
if(a===u.y)return A.dj}return null},
fC(a){var t=this,s=A.fy
if(A.a0(t))s=A.fu
else if(t===u.K)s=A.fs
else if(A.am(t)){s=A.fA
if(t===u.w)s=A.fn
else if(t===u.v)s=A.ft
else if(t===u.u)s=A.fj
else if(t===u.n)s=A.fr
else if(t===u.I)s=A.fl
else if(t===u.z)s=A.fp}else if(t===u.S)s=A.fm
else if(t===u.N)s=A.e_
else if(t===u.y)s=A.dZ
else if(t===u.H)s=A.fq
else if(t===u.i)s=A.fk
else if(t===u.m)s=A.fo
t.a=s
return t.a(a)},
fz(a){var t=this
if(a==null)return A.am(t)
return A.hb(v.typeUniverse,A.ha(a,t),t)},
fB(a){if(a==null)return!0
return this.x.b(a)},
fO(a){var t,s=this
if(a==null)return A.am(s)
t=s.f
if(a instanceof A.k)return!!a[t]
return!!J.a_(a)[t]},
fJ(a){var t,s=this
if(a==null)return A.am(s)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
t=s.f
if(a instanceof A.k)return!!a[t]
return!!J.a_(a)[t]},
fI(a){var t=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.k)return!!a[t.f]
return!0}if(typeof a=="function")return!0
return!1},
e5(a){if(typeof a=="object"){if(a instanceof A.k)return u.m.b(a)
return!0}if(typeof a=="function")return!0
return!1},
fy(a){var t=this
if(a==null){if(A.am(t))return a}else if(t.b(a))return a
throw A.q(A.e2(a,t),new Error())},
fA(a){var t=this
if(a==null||t.b(a))return a
throw A.q(A.e2(a,t),new Error())},
e2(a,b){return new A.aX("TypeError: "+A.dL(a,A.w(b,null)))},
dL(a,b){return A.c5(a)+": type '"+A.w(A.fX(a),null)+"' is not a subtype of type '"+b+"'"},
y(a,b){return new A.aX("TypeError: "+A.dL(a,b))},
fF(a){var t=this
return t.x.b(a)||A.db(v.typeUniverse,t).b(a)},
fL(a){return a!=null},
fs(a){if(a!=null)return a
throw A.q(A.y(a,"Object"),new Error())},
fP(a){return!0},
fu(a){return a},
e6(a){return!1},
dj(a){return!0===a||!1===a},
dZ(a){if(!0===a)return!0
if(!1===a)return!1
throw A.q(A.y(a,"bool"),new Error())},
fj(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.q(A.y(a,"bool?"),new Error())},
fk(a){if(typeof a=="number")return a
throw A.q(A.y(a,"double"),new Error())},
fl(a){if(typeof a=="number")return a
if(a==null)return a
throw A.q(A.y(a,"double?"),new Error())},
fG(a){return typeof a=="number"&&Math.floor(a)===a},
fm(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.q(A.y(a,"int"),new Error())},
fn(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.q(A.y(a,"int?"),new Error())},
fK(a){return typeof a=="number"},
fq(a){if(typeof a=="number")return a
throw A.q(A.y(a,"num"),new Error())},
fr(a){if(typeof a=="number")return a
if(a==null)return a
throw A.q(A.y(a,"num?"),new Error())},
fN(a){return typeof a=="string"},
e_(a){if(typeof a=="string")return a
throw A.q(A.y(a,"String"),new Error())},
ft(a){if(typeof a=="string")return a
if(a==null)return a
throw A.q(A.y(a,"String?"),new Error())},
fo(a){if(A.e5(a))return a
throw A.q(A.y(a,"JSObject"),new Error())},
fp(a){if(a==null)return a
if(A.e5(a))return a
throw A.q(A.y(a,"JSObject?"),new Error())},
e9(a,b){var t,s,r
for(t="",s="",r=0;r<a.length;++r,s=", ")t+=s+A.w(a[r],b)
return t},
fU(a,b){var t,s,r,q,p,o,n=a.x,m=a.y
if(""===n)return"("+A.e9(m,b)+")"
t=m.length
s=n.split(",")
r=s.length-t
for(q="(",p="",o=0;o<t;++o,p=", "){q+=p
if(r===0)q+="{"
q+=A.w(m[o],b)
if(r>=0)q+=" "+s[r];++r}return q+"})"},
e3(a0,a1,a2){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b=", ",a=null
if(a2!=null){t=a2.length
if(a1==null)a1=A.d([],u.s)
else a=a1.length
s=a1.length
for(r=t;r>0;--r)a1.push("T"+(s+r))
for(q=u.X,p="<",o="",r=0;r<t;++r,o=b){p=p+o+a1[a1.length-1-r]
n=a2[r]
m=n.w
if(!(m===2||m===3||m===4||m===5||n===q))p+=" extends "+A.w(n,a1)}p+=">"}else p=""
q=a0.x
l=a0.y
k=l.a
j=k.length
i=l.b
h=i.length
g=l.c
f=g.length
e=A.w(q,a1)
for(d="",c="",r=0;r<j;++r,c=b)d+=c+A.w(k[r],a1)
if(h>0){d+=c+"["
for(c="",r=0;r<h;++r,c=b)d+=c+A.w(i[r],a1)
d+="]"}if(f>0){d+=c+"{"
for(c="",r=0;r<f;r+=3,c=b){d+=c
if(g[r+1])d+="required "
d+=A.w(g[r+2],a1)+" "+g[r]}d+="}"}if(a!=null){a1.toString
a1.length=a}return p+"("+d+") => "+e},
w(a,b){var t,s,r,q,p,o,n=a.w
if(n===5)return"erased"
if(n===2)return"dynamic"
if(n===3)return"void"
if(n===1)return"Never"
if(n===4)return"any"
if(n===6){t=a.x
s=A.w(t,b)
r=t.w
return(r===11||r===12?"("+s+")":s)+"?"}if(n===7)return"FutureOr<"+A.w(a.x,b)+">"
if(n===8){q=A.h_(a.x)
p=a.y
return p.length>0?q+("<"+A.e9(p,b)+">"):q}if(n===10)return A.fU(a,b)
if(n===11)return A.e3(a,b,null)
if(n===12)return A.e3(a.x,b,a.y)
if(n===13){o=a.x
return b[b.length-1-o]}return"?"},
h_(a){var t=A.ej(a)
if(t!=null)return t
return"minified:"+a},
fi(a,b){var t=a.tR[b]
while(typeof t=="string")t=a.tR[t]
return t},
fh(a,b){var t,s,r,q,p,o=a.eT,n=o[b]
if(n==null)return A.cm(a,b,!1)
else if(typeof n=="number"){t=n
s=A.b_(a,5,"#")
r=A.co(t)
for(q=0;q<t;++q)r[q]=s
p=A.aZ(a,b,r)
o[b]=p
return p}else return n},
ff(a,b){return A.dW(a.tR,b)},
fe(a,b){return A.dW(a.eT,b)},
cm(a,b,c){var t,s=a.eC,r=s.get(b)
if(r!=null)return r
t=A.dV(a,null,b,!1)
s.set(b,t)
return t},
cn(a,b,c){var t,s,r=b.z
if(r==null)r=b.z=new Map()
t=r.get(c)
if(t!=null)return t
s=A.dV(a,b,c,!0)
r.set(c,s)
return s},
fg(a,b,c){var t,s,r,q=b.Q
if(q==null)q=b.Q=new Map()
t=c.as
s=q.get(t)
if(s!=null)return s
r=A.dd(a,b,c.w===9?c.y:[c])
q.set(t,r)
return r},
dV(a,b,c,d){return A.f7(A.f1(a,b,c,d))},
N(a,b){b.a=A.fC
b.b=A.fD
return b},
b_(a,b,c){var t,s,r=a.eC.get(c)
if(r!=null)return r
t=new A.z(null,null)
t.w=b
t.as=c
s=A.N(a,t)
a.eC.set(c,s)
return s},
dT(a,b,c){var t,s=b.as+"?",r=a.eC.get(s)
if(r!=null)return r
t=A.fc(a,b,s,c)
a.eC.set(s,t)
return t},
fc(a,b,c,d){var t,s,r
if(d){t=b.w
s=!0
if(!A.a0(b))if(!(b===u.P||b===u.T))if(t!==6)s=t===7&&A.am(b.x)
if(s)return b
else if(t===1)return u.P}r=new A.z(null,null)
r.w=6
r.x=b
r.as=c
return A.N(a,r)},
dS(a,b,c){var t,s=b.as+"/",r=a.eC.get(s)
if(r!=null)return r
t=A.fa(a,b,s,c)
a.eC.set(s,t)
return t},
fa(a,b,c,d){var t,s
if(d){t=b.w
if(A.a0(b)||b===u.K)return b
else if(t===1)return A.aZ(a,"dz",[b])
else if(b===u.P||b===u.T)return u.Q}s=new A.z(null,null)
s.w=7
s.x=b
s.as=c
return A.N(a,s)},
fd(a,b){var t,s,r=""+b+"^",q=a.eC.get(r)
if(q!=null)return q
t=new A.z(null,null)
t.w=13
t.x=b
t.as=r
s=A.N(a,t)
a.eC.set(r,s)
return s},
aY(a){var t,s,r,q=a.length
for(t="",s="",r=0;r<q;++r,s=",")t+=s+a[r].as
return t},
f9(a){var t,s,r,q,p,o=a.length
for(t="",s="",r=0;r<o;r+=3,s=","){q=a[r]
p=a[r+1]?"!":":"
t+=s+q+p+a[r+2].as}return t},
aZ(a,b,c){var t,s,r,q=b
if(c.length>0)q+="<"+A.aY(c)+">"
t=a.eC.get(q)
if(t!=null)return t
s=new A.z(null,null)
s.w=8
s.x=b
s.y=c
if(c.length>0)s.c=c[0]
s.as=q
r=A.N(a,s)
a.eC.set(q,r)
return r},
dd(a,b,c){var t,s,r,q,p,o
if(b.w===9){t=b.x
s=b.y.concat(c)}else{s=c
t=b}r=t.as+(";<"+A.aY(s)+">")
q=a.eC.get(r)
if(q!=null)return q
p=new A.z(null,null)
p.w=9
p.x=t
p.y=s
p.as=r
o=A.N(a,p)
a.eC.set(r,o)
return o},
dU(a,b,c){var t,s,r="+"+(b+"("+A.aY(c)+")"),q=a.eC.get(r)
if(q!=null)return q
t=new A.z(null,null)
t.w=10
t.x=b
t.y=c
t.as=r
s=A.N(a,t)
a.eC.set(r,s)
return s},
dR(a,b,c){var t,s,r,q,p,o=b.as,n=c.a,m=n.length,l=c.b,k=l.length,j=c.c,i=j.length,h="("+A.aY(n)
if(k>0){t=m>0?",":""
h+=t+"["+A.aY(l)+"]"}if(i>0){t=m>0?",":""
h+=t+"{"+A.f9(j)+"}"}s=o+(h+")")
r=a.eC.get(s)
if(r!=null)return r
q=new A.z(null,null)
q.w=11
q.x=b
q.y=c
q.as=s
p=A.N(a,q)
a.eC.set(s,p)
return p},
de(a,b,c,d){var t,s=b.as+("<"+A.aY(c)+">"),r=a.eC.get(s)
if(r!=null)return r
t=A.fb(a,b,c,s,d)
a.eC.set(s,t)
return t},
fb(a,b,c,d,e){var t,s,r,q,p,o,n,m
if(e){t=c.length
s=A.co(t)
for(r=0,q=0;q<t;++q){p=c[q]
if(p.w===1){s[q]=p;++r}}if(r>0){o=A.X(a,b,s,0)
n=A.ai(a,c,s,0)
return A.de(a,o,n,c!==n)}}m=new A.z(null,null)
m.w=12
m.x=b
m.y=c
m.as=d
return A.N(a,m)},
f1(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
f7(a){var t,s,r,q,p,o,n,m=a.r,l=a.s
for(t=m.length,s=0;s<t;){r=m.charCodeAt(s)
if(r>=48&&r<=57)s=A.f3(s+1,r,m,l)
else if((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124)s=A.dO(a,s,m,l,!1)
else if(r===46)s=A.dO(a,s,m,l,!0)
else{++s
switch(r){case 44:break
case 58:l.push(!1)
break
case 33:l.push(!0)
break
case 59:l.push(A.V(a.u,a.e,l.pop()))
break
case 94:l.push(A.fd(a.u,l.pop()))
break
case 35:l.push(A.b_(a.u,5,"#"))
break
case 64:l.push(A.b_(a.u,2,"@"))
break
case 126:l.push(A.b_(a.u,3,"~"))
break
case 60:l.push(a.p)
a.p=l.length
break
case 62:A.f5(a,l)
break
case 38:A.f4(a,l)
break
case 63:q=a.u
l.push(A.dT(q,A.V(q,a.e,l.pop()),a.n))
break
case 47:q=a.u
l.push(A.dS(q,A.V(q,a.e,l.pop()),a.n))
break
case 40:l.push(-3)
l.push(a.p)
a.p=l.length
break
case 41:A.f2(a,l)
break
case 91:l.push(a.p)
a.p=l.length
break
case 93:p=l.splice(a.p)
A.dP(a.u,a.e,p)
a.p=l.pop()
l.push(p)
l.push(-1)
break
case 123:l.push(a.p)
a.p=l.length
break
case 125:p=l.splice(a.p)
A.f8(a.u,a.e,p)
a.p=l.pop()
l.push(p)
l.push(-2)
break
case 43:o=m.indexOf("(",s)
l.push(m.substring(s,o))
l.push(-4)
l.push(a.p)
a.p=l.length
s=o+1
break
default:throw"Bad character "+r}}}n=l.pop()
return A.V(a.u,a.e,n)},
f3(a,b,c,d){var t,s,r=b-48
for(t=c.length;a<t;++a){s=c.charCodeAt(a)
if(!(s>=48&&s<=57))break
r=r*10+(s-48)}d.push(r)
return a},
dO(a,b,c,d,e){var t,s,r,q,p,o,n=b+1
for(t=c.length;n<t;++n){s=c.charCodeAt(n)
if(s===46){if(e)break
e=!0}else{if(!((((s|32)>>>0)-97&65535)<26||s===95||s===36||s===124))r=s>=48&&s<=57
else r=!0
if(!r)break}}q=c.substring(b,n)
if(e){t=a.u
p=a.e
if(p.w===9)p=p.x
o=A.fi(t,p.x)[q]
if(o==null)A.c0('No "'+q+'" in "'+A.eW(p)+'"')
d.push(A.cn(t,p,o))}else d.push(q)
return n},
f5(a,b){var t,s=a.u,r=A.dN(a,b),q=b.pop()
if(typeof q=="string")b.push(A.aZ(s,q,r))
else{t=A.V(s,a.e,q)
switch(t.w){case 11:b.push(A.de(s,t,r,a.n))
break
default:b.push(A.dd(s,t,r))
break}}},
f2(a,b){var t,s,r,q=a.u,p=b.pop(),o=null,n=null
if(typeof p=="number")switch(p){case-1:o=b.pop()
break
case-2:n=b.pop()
break
default:b.push(p)
break}else b.push(p)
t=A.dN(a,b)
p=b.pop()
switch(p){case-3:p=b.pop()
if(o==null)o=q.sEA
if(n==null)n=q.sEA
s=A.V(q,a.e,p)
r=new A.bV()
r.a=t
r.b=o
r.c=n
b.push(A.dR(q,s,r))
return
case-4:b.push(A.dU(q,b.pop(),t))
return
default:throw A.i(A.b4("Unexpected state under `()`: "+A.n(p)))}},
f4(a,b){var t=b.pop()
if(0===t){b.push(A.b_(a.u,1,"0&"))
return}if(1===t){b.push(A.b_(a.u,4,"1&"))
return}throw A.i(A.b4("Unexpected extended operation "+A.n(t)))},
dN(a,b){var t=b.splice(a.p)
A.dP(a.u,a.e,t)
a.p=b.pop()
return t},
V(a,b,c){if(typeof c=="string")return A.aZ(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.f6(a,b,c)}else return c},
dP(a,b,c){var t,s=c.length
for(t=0;t<s;++t)c[t]=A.V(a,b,c[t])},
f8(a,b,c){var t,s=c.length
for(t=2;t<s;t+=3)c[t]=A.V(a,b,c[t])},
f6(a,b,c){var t,s,r=b.w
if(r===9){if(c===0)return b.x
t=b.y
s=t.length
if(c<=s)return t[c-1]
c-=s
b=b.x
r=b.w}else if(c===0)return b
if(r!==8)throw A.i(A.b4("Indexed base must be an interface type"))
t=b.y
if(c<=t.length)return t[c-1]
throw A.i(A.b4("Bad index "+c+" for "+b.h(0)))},
hb(a,b,c){var t,s=b.d
if(s==null)s=b.d=new Map()
t=s.get(c)
if(t==null){t=A.l(a,b,null,c,null)
s.set(c,t)}return t},
l(a,b,c,d,e){var t,s,r,q,p,o,n,m,l,k,j
if(b===d)return!0
if(A.a0(d))return!0
t=b.w
if(t===4)return!0
if(A.a0(b))return!1
if(b.w===1)return!0
s=t===13
if(s)if(A.l(a,c[b.x],c,d,e))return!0
r=d.w
q=u.P
if(b===q||b===u.T){if(r===7)return A.l(a,b,c,d.x,e)
return d===q||d===u.T||r===6}if(d===u.K){if(t===7)return A.l(a,b.x,c,d,e)
return t!==6}if(t===7){if(!A.l(a,b.x,c,d,e))return!1
return A.l(a,A.db(a,b),c,d,e)}if(t===6)return A.l(a,q,c,d,e)&&A.l(a,b.x,c,d,e)
if(r===7){if(A.l(a,b,c,d.x,e))return!0
return A.l(a,b,c,A.db(a,d),e)}if(r===6)return A.l(a,b,c,q,e)||A.l(a,b,c,d.x,e)
if(s)return!1
q=t!==11
if((!q||t===12)&&d===u.Z)return!0
p=t===10
if(p&&d===u.L)return!0
if(r===12){if(b===u.g)return!0
if(t!==12)return!1
o=b.y
n=d.y
m=o.length
if(m!==n.length)return!1
c=c==null?o:o.concat(c)
e=e==null?n:n.concat(e)
for(l=0;l<m;++l){k=o[l]
j=n[l]
if(!A.l(a,k,c,j,e)||!A.l(a,j,e,k,c))return!1}return A.e4(a,b.x,c,d.x,e)}if(r===11){if(b===u.g)return!0
if(q)return!1
return A.e4(a,b,c,d,e)}if(t===8){if(r!==8)return!1
return A.fH(a,b,c,d,e)}if(p&&r===10)return A.fM(a,b,c,d,e)
return!1},
e4(a2,a3,a4,a5,a6){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1
if(!A.l(a2,a3.x,a4,a5.x,a6))return!1
t=a3.y
s=a5.y
r=t.a
q=s.a
p=r.length
o=q.length
if(p>o)return!1
n=o-p
m=t.b
l=s.b
k=m.length
j=l.length
if(p+k<o+j)return!1
for(i=0;i<p;++i){h=r[i]
if(!A.l(a2,q[i],a6,h,a4))return!1}for(i=0;i<n;++i){h=m[i]
if(!A.l(a2,q[p+i],a6,h,a4))return!1}for(i=0;i<j;++i){h=m[n+i]
if(!A.l(a2,l[i],a6,h,a4))return!1}g=t.c
f=s.c
e=g.length
d=f.length
for(c=0,b=0;b<d;b+=3){a=f[b]
for(;;){if(c>=e)return!1
a0=g[c]
c+=3
if(a<a0)return!1
a1=g[c-2]
if(a0<a){if(a1)return!1
continue}h=f[b+1]
if(a1&&!h)return!1
h=g[c-1]
if(!A.l(a2,f[b+2],a6,h,a4))return!1
break}}while(c<e){if(g[c+1])return!1
c+=3}return!0},
fH(a,b,c,d,e){var t,s,r,q,p,o=b.x,n=d.x
while(o!==n){t=a.tR[o]
if(t==null)return!1
if(typeof t=="string"){o=t
continue}s=t[n]
if(s==null)return!1
r=s.length
q=r>0?new Array(r):v.typeUniverse.sEA
for(p=0;p<r;++p)q[p]=A.cn(a,b,s[p])
return A.dY(a,q,null,c,d.y,e)}return A.dY(a,b.y,null,c,d.y,e)},
dY(a,b,c,d,e,f){var t,s=b.length
for(t=0;t<s;++t)if(!A.l(a,b[t],d,e[t],f))return!1
return!0},
fM(a,b,c,d,e){var t,s=b.y,r=d.y,q=s.length
if(q!==r.length)return!1
if(b.x!==d.x)return!1
for(t=0;t<q;++t)if(!A.l(a,s[t],c,r[t],e))return!1
return!0},
am(a){var t=a.w,s=!0
if(!(a===u.P||a===u.T))if(!A.a0(a))if(t!==6)s=t===7&&A.am(a.x)
return s},
a0(a){var t=a.w
return t===2||t===3||t===4||t===5||a===u.X},
dW(a,b){var t,s,r=Object.keys(b),q=r.length
for(t=0;t<q;++t){s=r[t]
a[s]=b[s]}},
co(a){return a>0?new Array(a):v.typeUniverse.sEA},
z:function z(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
bV:function bV(){this.c=this.b=this.a=null},
cl:function cl(a){this.a=a},
bU:function bU(){},
aX:function aX(a){this.a=a},
dQ(a,b,c){return 0},
bZ:function bZ(a){var _=this
_.a=a
_.e=_.d=_.c=_.b=null},
ag:function ag(a,b){this.a=a
this.$ti=b},
eT(a,b){return new A.C(a.i("@<0>").B(b).i("C<1,2>"))},
eU(a,b,c){return A.h4(a,new A.C(b.i("@<0>").B(c).i("C<1,2>")))},
dC(a,b){return new A.C(a.i("@<0>").B(b).i("C<1,2>"))},
bp(a){return new A.aR(a.i("aR<0>"))},
dc(){var t=Object.create(null)
t["<non-identifier-key>"]=t
delete t["<non-identifier-key>"]
return t},
dM(a,b,c){var t=new A.af(a,b,c.i("af<0>"))
t.c=a.e
return t},
da(a){var t,s
if(A.dq(a))return"{...}"
t=new A.bM("")
try{s={}
$.Y.push(a)
t.a+="{"
s.a=!0
a.L(0,new A.ca(s,t))
t.a+="}"}finally{$.Y.pop()}s=t.a
return s.charCodeAt(0)==0?s:s},
aR:function aR(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
cj:function cj(a){this.a=a
this.c=this.b=null},
af:function af(a,b,c){var _=this
_.a=a
_.b=b
_.d=_.c=null
_.$ti=c},
f:function f(){},
br:function br(){},
ca:function ca(a,b){this.a=a
this.b=b},
aK:function aK(){},
aW:function aW(){},
aD(a,b){var t,s
if(Array.isArray(a))return A.d(a.slice(0),b.i("m<0>"))
t=A.d([],b.i("m<0>"))
for(s=J.c2(a);s.k();)t.push(s.gl())
return t},
dI(a,b,c){var t=J.c2(b)
if(!t.k())return a
if(c.length===0){do a+=A.n(t.gl())
while(t.k())}else{a+=A.n(t.gl())
while(t.k())a=a+c+A.n(t.gl())}return a},
dG(){return A.h5(new Error())},
c5(a){if(typeof a=="number"||A.dj(a)||a==null)return J.b1(a)
if(typeof a=="string")return JSON.stringify(a)
return A.eV(a)},
b4(a){return new A.b3(a)},
dt(a,b){return new A.ao(!1,null,b,a)},
dK(a){return new A.bQ(a)},
dH(a){return new A.bK(a)},
ar(a){return new A.b7(a)},
eJ(a){return new A.ch(a)},
eP(a,b,c){var t,s
if(A.dq(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}t=A.d([],u.s)
$.Y.push(a)
try{A.fQ(a,t)}finally{$.Y.pop()}s=A.dI(b,t,", ")+c
return s.charCodeAt(0)==0?s:s},
d7(a,b,c){var t,s
if(A.dq(a))return b+"..."+c
t=new A.bM(b)
$.Y.push(a)
try{s=t
s.a=A.dI(s.a,a,", ")}finally{$.Y.pop()}t.a+=c
s=t.a
return s.charCodeAt(0)==0?s:s},
fQ(a,b){var t,s,r,q,p,o,n,m=a.gq(a),l=0,k=0
for(;;){if(!(l<80||k<3))break
if(!m.k())return
t=A.n(m.gl())
b.push(t)
l+=t.length+2;++k}if(!m.k()){if(k<=5)return
s=b.pop()
r=b.pop()}else{q=m.gl();++k
if(!m.k()){if(k<=4){b.push(A.n(q))
return}s=A.n(q)
r=b.pop()
l+=s.length+2}else{p=m.gl();++k
for(;m.k();q=p,p=o){o=m.gl();++k
if(k>100){for(;;){if(!(l>75&&k>3))break
l-=b.pop().length+2;--k}b.push("...")
return}}r=A.n(q)
s=A.n(p)
l+=s.length+r.length+4}}if(k>b.length+2){l+=5
n="..."}else n=null
for(;;){if(!(l>80&&b.length>3))break
l-=b.pop().length+2
if(n==null){l+=5
n="..."}}if(n!=null)b.push(n)
b.push(r)
b.push(s)},
eh(a){A.hh(a)},
cg:function cg(){},
j:function j(){},
b3:function b3(a){this.a=a},
aO:function aO(){},
ao:function ao(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
bS:function bS(a){this.a=a},
bQ:function bQ(a){this.a=a},
bK:function bK(a){this.a=a},
b7:function b7(a){this.a=a},
aN:function aN(){},
ch:function ch(a){this.a=a},
o:function o(){},
D:function D(a,b,c){this.a=a
this.b=b
this.$ti=c},
T:function T(){},
k:function k(){},
bM:function bM(a){this.a=a},
a2:function a2(a,b){this.b=a
this.e=b
this.r=!1},
fT(a,b){var t
if(b.a===0)return a
t=u.N
t=A.eT(t,t)
t.E(0,b)
t.E(0,a)
return t},
O(a,b,c,d,e,f,g){var t=!1
if(c==null)if(d==null)t=g==null
if(t)return null
t=A.dC(u.N,u.W)
if(c!=null)t.v(0,"click",c)
if(d!=null)t.v(0,"input",d)
if(g!=null)t.v(0,"submit",g)
return t},
u(a,b,c){var t=null
return new A.b9("div",t,b,t,t,A.O(t,t,c,t,t,t,t),a)},
cd(a,b){var t=null
return new A.ae("span",b,a,t,t,A.O(t,t,t,t,t,t,t),B.a)},
bB(a,b){var t=null
return new A.ac("p",b,a,t,t,A.O(t,t,t,t,t,t,t),B.a)},
dA(a,b){var t=null
return new A.bf("h2",b,a,t,t,A.O(t,t,t,t,t,t,t),B.a)},
ap(a,b,c,d){var t=null
return new A.a4("button",d,b,t,a,A.O(t,t,c,t,t,t,t),B.a)},
dF(a,b){var t=null
return new A.bG("section",t,b,t,t,t,a)},
b:function b(){},
bO:function bO(){},
au:function au(){},
H:function H(a){this.a=a},
bq:function bq(){},
bH:function bH(){},
aw:function aw(){},
c6:function c6(a){this.a=a},
M:function M(a){this.a=a},
L:function L(a){this.a=a},
aL:function aL(a,b,c){this.a=a
this.b=b
this.c=c},
a6:function a6(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.$ti=d},
b9:function b9(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
ae:function ae(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
ac:function ac(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
be:function be(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
bf:function bf(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
a4:function a4(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
bh:function bh(a,b,c,d,e,f,g){var _=this
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
a8:function a8(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
bd:function bd(a,b,c,d,e,f,g){var _=this
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
bc:function bc(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
bG:function bG(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
hf(a,b){var t,s,r=A.bp(u.M),q=A.cw(a,new A.bX(r))
for(t=q.length,s=0;s<q.length;q.length===t||(0,A.an)(q),++s)b.appendChild(q[s])
A.aD(r,r.$ti.c)
return new A.c3()},
cw(a2,a3){var t,s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=null,a1=a2 instanceof A.M
if(a1)t=a2.a
else t=a0
if(a1)return A.d([v.G.document.createTextNode(t)],u.O)
a1=a2 instanceof A.au
s=a0
t=a0
r=a0
q=a0
p=a0
o=a0
if(a1){n=a2.a
m=a2.b
r=a2.c
q=a2.e
p=a2.f
s=a2.r
o=s
t=m}else n=a0
if(a1){l=v.G
k=l.document.createElement(n)
if(r!=null)k.className=r
if(q!=null)for(j=q.gK(),j=j.gq(j);j.k();){i=j.gl()
k.setAttribute(i.a,i.b)}if(p!=null)for(j=new A.R(p,A.ah(p).i("R<1,2>")).gq(0);j.k();){h=j.d
A.fv(k,h.a,h.b)}if(t!=null)k.appendChild(l.document.createTextNode(t))
for(l=o.length,g=0;g<o.length;o.length===l||(0,A.an)(o),++g){f=A.cw(o[g],a3)
for(j=f.length,e=0;e<f.length;f.length===j||(0,A.an)(f),++e)k.appendChild(f[e])}return A.d([k],u.O)}d=a2 instanceof A.H
if(d)o=a2.a
else o=a0
if(d){c=A.d([],u.O)
for(l=o.length,g=0;g<o.length;o.length===l||(0,A.an)(o),++g)B.p.E(c,A.cw(o[g],a3))
return c}l=a2 instanceof A.L
b=l?a2.a:a0
if(l){a=v.G.document.createElement("span")
a.setAttribute("data-bloom-live","")
A.df(a,a3,b,a0)
return A.d([a],u.O)}l={}
l.a=l.b=null
j=a2 instanceof A.aL
if(j){l.b=a2.b
l.a=a2.c}if(j){a=v.G.document.createElement("span")
a.setAttribute("data-bloom-show","")
A.df(a,a3,new A.cx(l,a2),a0)
return A.d([a],u.O)}if(a2 instanceof A.a6){a=v.G.document.createElement("span")
a.setAttribute("data-bloom-foreach","")
A.df(a,a3,new A.cy(a2),new A.cz())
return A.d([a],u.O)}},
df(a,b,c,d){var t=new A.bX(A.bp(u.M))
b.a.ae(0,new A.cr(A.h3(new A.cs(new A.ct(t,c,d,a))),t))},
fv(a,b,c){var t,s=new A.cp(b,c)
if(typeof s=="function")A.c0(A.dt("Attempting to rewrap a JS function.",null))
t=function(d,e){return function(f){return d(e,f,arguments.length)}}(A.fw,s)
t[$.ds()]=s
a.addEventListener(b,t)},
h1(a,b){var t,s,r,q=null,p=null
try{t=b.target
if(t!=null){s=t
q=A.fS(s,"value")
p=A.fR(s,"checked")}}catch(r){}return new A.a2(q,new A.cA(b))},
fS(a,b){var t,s,r
try{t=v.G.Reflect.get(a,b)
if(t==null)return null
if(t!=null&&typeof t==="string"){s=A.e_(t)
return s}return null}catch(r){return null}},
fR(a,b){var t,s,r
try{t=v.G.Reflect.get(a,b)
if(t==null)return null
if(t!=null&&typeof t==="boolean"){s=A.dZ(t)
return s}return null}catch(r){return null}},
c3:function c3(){},
bX:function bX(a){this.a=a},
cx:function cx(a,b){this.a=a
this.b=b},
cy:function cy(a){this.a=a},
cz:function cz(){},
ct:function ct(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
cs:function cs(a){this.a=a},
cr:function cr(a,b){this.a=a
this.b=b},
cp:function cp(a,b){this.a=a
this.b=b},
cA:function cA(a){this.a=a},
dh(){var t,s,r,q,p,o,n=$.F
if(n>1){$.F=n-1
return}t=null
s=!1
while(n=$.cq,n!=null){r=n
$.cq=null
$.cu=$.cu+1
while(r!=null){p=r.f
r.f=null
r.r&=4294967293
if((r.r&8)===0&&A.e7(r))try{r.P()}catch(o){q=A.el(o)
if(!s){t=q
s=!0}}r=p}}$.cu=0
$.F=$.F-1
if(s)throw A.i(t)},
dl(a,b){var t=$.cv,s=$.b0+1
$.b0=s
return new A.aq(a,t-1,!1,null,s,A.bp(u.M),b.i("aq<0>"))},
h3(a){var t,s=$.b0+1
$.b0=s
t=new A.ba(a,null,s,A.bp(u.M))
t.a2(a,null)
return t.gah()},
eX(a,b,c,d){var t=$.b0+1
$.b0=t
t=new A.aM(a,new A.cc(d),!1,c,t,A.bp(u.M),d.i("aM<0>"))
t.z=a
return t},
d5(a,b){return A.eX(a,!1,null,b)},
dX(a){var t,s,r,q=null,p=$.t
if(p==null)return q
t=a.f
if(t==null||t.d!==p){p=p.gn()
s=$.t
t=new A.ck(a,p,q,s,q,q,0,t)
if(s.gn()!=null)$.t.gn().c=t
$.t.sn(t)
a.f=t
if(($.t.gR()&32)!==0)a.D(t)
return t}else if(t.r===-1){t.r=0
s=t.c
if(s!=null){s.b=t.b
r=t.b
if(r!=null)r.c=s
t.b=p.gn()
t.c=null
$.t.gn().c=t
$.t.sn(t)}return t}return q},
e7(a){var t,s
for(t=a.gn();t!=null;t=t.c){s=t.a
if(s.e!==t.r||!s.J()||s.e!==t.r)return!0}return!1},
e8(a){var t,s,r,q
for(t=a.gn();t!=null;t=q){s=t.a
r=s.f
if(r!=null)t.w=r
s.f=t
t.r=-1
q=t.c
if(q==null){a.sn(t)
break}}},
e1(a){var t,s,r,q,p=a.gn()
for(t=null;p!=null;p=s){s=p.b
if(p.r===-1){p.a.A(p)
if(s!=null)s.c=p.c
r=p.c
if(r!=null)r.b=s}else t=p
r=p.a
q=p.w
r.f=q
if(q!=null)p.w=null}a.sn(t)},
e0(a){var t,s,r=a.d
a.d=null
if(r!=null){$.F=$.F+1
t=$.t
$.t=null
try{r.$0()}catch(s){a.r=(a.r&=4294967294)|8
A.dg(a)
throw s}finally{$.t=t
A.dh()}}},
dg(a){var t
for(t=a.e;t!=null;t=t.c)t.a.A(t)
a.e=a.a=null
A.e0(a)},
aq:function aq(a,b,c,d,e,f,g){var _=this
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
ba:function ba(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.f=_.e=_.d=null
_.r=32
_.w=d
_.x=!1},
c4:function c4(a,b){this.a=a
this.b=b},
ad:function ad(){},
aM:function aM(a,b,c,d,e,f,g){var _=this
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
cc:function cc(a){this.a=a},
ck:function ck(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
bI:function bI(){},
bJ:function bJ(a){this.a=a},
a5:function a5(){},
hd(){var t,s,r,q,p,o,n,m=null,l="p-5 bg-[#14141A] border border-[#27272A] rounded-xl space-y-4 shadow-xl",k="flex items-center justify-between",j="text-sm font-semibold text-zinc-300 uppercase tracking-wider",i="p-3 bg-[#09090B] border border-[#1E1E24] rounded-lg",h="text-xs text-zinc-500",g=u.S,f=A.d5(0,g),e=u.B,d=A.d5(A.d([B.I,B.J,B.H],u.V),e),c=A.d5(B.h,u.U),b=u.N,a=A.d5("",b),a0=A.dl(new A.cO(f),g),a1=A.dl(new A.cP(c,d),e),a2=A.dl(new A.cQ(d),g)
g=u.t
e=A.d([A.u(A.d([A.u(B.y,"w-7 h-7 rounded-md bg-indigo-600 flex items-center justify-center font-bold text-white text-sm shadow-md shadow-indigo-500/20",m),new A.be("h1","Bloom JS Native","text-2xl font-bold tracking-tight text-zinc-100",m,m,A.O(m,m,m,m,m,m,m),B.a),A.cd("px-2 py-0.5 text-xs font-mono bg-[#14141A] border border-[#27272A] rounded text-zinc-400","v0.1.0")],g),"flex items-center space-x-3",m),A.bB("text-sm text-zinc-400","Dart-owned reactivity with native DOM rendering and zero Flutter overhead.")],g)
t=A.dF(A.d([A.u(A.d([A.dA(j,"Reactive State Engine"),A.cd("text-xs text-indigo-400 font-mono","signals ^5.5.0")],g),k,m),A.u(A.d([A.u(A.d([A.bB(h,"Primary Signal"),new A.L(new A.cU(f))],g),i,m),A.u(A.d([A.bB(h,"Computed 2x"),new A.L(new A.cV(a0))],g),i,m)],g),"grid grid-cols-2 gap-4 py-2",m),A.u(A.d([A.ap(m,"px-3 py-1.5 text-xs font-medium bg-[#1E1E24] hover:bg-[#27272A] text-zinc-300 border border-[#27272A] rounded-lg transition-colors cursor-pointer",new A.cW(f),"Decrement (-1)"),A.ap(m,"px-3 py-1.5 text-xs font-medium bg-indigo-600 hover:bg-indigo-500 text-white rounded-lg shadow-sm shadow-indigo-600/30 transition-colors cursor-pointer",new A.cX(f),"Increment (+1)"),A.ap(m,"px-3 py-1.5 text-xs font-medium text-zinc-400 hover:text-zinc-200 transition-colors cursor-pointer",new A.cY(f),"Reset")],g),"flex items-center space-x-2",m),new A.aL(new A.cZ(f),A.u(B.u,"px-3 py-2 bg-indigo-950/40 border border-indigo-800/50 rounded-lg text-xs text-indigo-300",m),A.u(B.v,"px-3 py-2 bg-[#09090B]/60 border border-[#1E1E24] rounded-lg text-xs text-zinc-500",m))],g),l)
s=A.u(A.d([A.dA(j,"Tasks & Fine-Grained DOM"),new A.L(new A.d_(a2))],g),k,m)
r=A.eU(["value",a.gj()],b,b)
b=A.dC(b,b)
b.v(0,"placeholder","Create new task descriptor...")
b=A.d([new A.bh("input",m,"flex-1 px-3.5 py-2 text-sm bg-[#09090B] border border-[#27272A] rounded-lg text-zinc-100 placeholder:text-zinc-600 focus:outline-none focus:border-indigo-500",m,A.fT(r,b),A.O(m,m,m,new A.d0(a),m,m,m),B.a),A.ap(B.z,"px-4 py-2 text-sm font-medium bg-indigo-600 hover:bg-indigo-500 text-white rounded-lg transition-colors cursor-pointer",m,"Add Task")],g)
r=A.O(m,m,m,m,m,m,new A.cN(a,d))
q=A.d([],g)
for(p=0;p<3;++p)q.push(new A.L(new A.cR(c,B.x[p])))
o=A.u(A.d([A.u(A.d([new A.bg("header",m,"border-b border-[#1E1E24] pb-6 space-y-2",m,m,m,e),t,A.dF(A.d([s,new A.bd("form",m,"flex gap-2",m,m,r,b),A.u(q,"flex space-x-1 border-b border-[#1E1E24] pb-2",m),new A.bP("ul",m,"space-y-2 pt-1",m,m,m,A.d([new A.a6(new A.cS(a1),new A.cT(new A.d3(d),new A.d1(d)),m,u.o)],g))],g),l),new A.bc("footer",m,"pt-4 border-t border-[#1E1E24] text-center text-xs text-zinc-600",m,m,m,B.w)],g),"max-w-2xl mx-auto px-6 py-12 space-y-8",m)],g),"min-h-screen bg-[#09090B] text-zinc-100 font-sans antialiased selection:bg-indigo-500 selection:text-white",m)
n=v.G.document.querySelector("#app")
if(n==null)A.c0(A.dH('Bloom mount: selector "#app" matched no element.'))
A.hf(o,n)},
r:function r(a,b,c){this.a=a
this.b=b
this.c=c},
U:function U(a,b){this.a=a
this.b=b},
cO:function cO(a){this.a=a},
cP:function cP(a,b){this.a=a
this.b=b},
cL:function cL(){},
cM:function cM(){},
cQ:function cQ(a){this.a=a},
cK:function cK(){},
cN:function cN(a,b){this.a=a
this.b=b},
d3:function d3(a){this.a=a},
d1:function d1(a){this.a=a},
d2:function d2(a){this.a=a},
cU:function cU(a){this.a=a},
cV:function cV(a){this.a=a},
cW:function cW(a){this.a=a},
cX:function cX(a){this.a=a},
cY:function cY(a){this.a=a},
cZ:function cZ(a){this.a=a},
d_:function d_(a){this.a=a},
d0:function d0(a){this.a=a},
cR:function cR(a,b){this.a=a
this.b=b},
cJ:function cJ(a,b){this.a=a
this.b=b},
cS:function cS(a){this.a=a},
cT:function cT(a,b){this.a=a
this.b=b},
cH:function cH(a,b){this.a=a
this.b=b},
cI:function cI(a,b){this.a=a
this.b=b},
ej(a){return v.mangledGlobalNames[a]},
hh(a){if(typeof dartPrint=="function"){dartPrint(a)
return}if(typeof console=="object"&&typeof console.log!="undefined"){console.log(a)
return}if(typeof print=="function"){print(a)
return}throw"Unable to print message: "+String(a)},
hj(a){throw A.q(new A.aC("Field '"+a+"' has been assigned during initialization."),new Error())},
a1(){throw A.q(A.eS(""),new Error())},
fw(a,b,c){if(c>=1)return a.$1(b)
return a.$0()}},B={}
var w=[A,J,B]
var $={}
A.d8.prototype={}
J.bi.prototype={
C(a,b){return a===b},
gp(a){return A.bD(a)},
h(a){return"Instance of '"+A.bE(a)+"'"},
gm(a){return A.Z(A.di(this))}}
J.bk.prototype={
h(a){return String(a)},
gp(a){return a?519018:218159},
gm(a){return A.Z(u.y)},
$ie:1}
J.ay.prototype={
C(a,b){return null==b},
h(a){return"null"},
gp(a){return 0},
$ie:1}
J.aA.prototype={$ih:1}
J.J.prototype={
gp(a){return 0},
h(a){return String(a)}}
J.bC.prototype={}
J.aP.prototype={}
J.I.prototype={
h(a){var t=a[$.em()]
if(t==null)t=a[$.ds()]
if(t==null)return this.a0(a)
return"JavaScript function for "+J.b1(t)},
$iQ:1}
J.az.prototype={
gp(a){return 0},
h(a){return String(a)}}
J.aB.prototype={
gp(a){return 0},
h(a){return String(a)}}
J.m.prototype={
E(a,b){a.$flags&1&&A.hk(a,"addAll",2)
this.a5(a,b)
return},
a5(a,b){var t,s=b.length
if(s===0)return
if(a===b)throw A.i(A.ar(a))
for(t=0;t<s;++t)a.push(b[t])},
Y(a,b,c){return new A.S(a,b,A.W(a).i("@<1>").B(c).i("S<1,2>"))},
F(a,b){return a[b]},
h(a){return A.d7(a,"[","]")},
gq(a){return new J.b2(a,a.length,A.W(a).i("b2<1>"))},
gp(a){return A.bD(a)},
gu(a){return a.length},
$ic:1}
J.bj.prototype={
ap(a){var t,s,r
if(!Array.isArray(a))return null
t=a.$flags|0
if((t&4)!==0)s="const, "
else if((t&2)!==0)s="unmodifiable, "
else s=(t&1)!==0?"fixed, ":""
r="Instance of '"+A.bE(a)+"'"
if(s==="")return r
return r+" ("+s+"length: "+a.length+")"}}
J.c7.prototype={}
J.b2.prototype={
gl(){var t=this.d
return t==null?this.$ti.c.a(t):t},
k(){var t,s=this,r=s.a,q=r.length
if(s.b!==q)throw A.i(A.an(r))
t=s.c
if(t>=q){s.d=null
return!1}s.d=r[t]
s.c=t+1
return!0}}
J.bm.prototype={
h(a){if(a===0&&1/a<0)return"-0.0"
else return""+a},
gp(a){var t,s,r,q,p=a|0
if(a===p)return p&536870911
t=Math.abs(a)
s=Math.log(t)/0.6931471805599453|0
r=Math.pow(2,s)
q=t<1?t/r:r/t
return((q*9007199254740992|0)+(q*3542243181176521|0))*599197+s*1259&536870911},
ac(a,b){var t
if(a>0)t=this.ab(a,b)
else{t=b>31?31:b
t=a>>t>>>0}return t},
ab(a,b){return b>31?0:a>>>b},
gm(a){return A.Z(u.H)},
$ip:1}
J.ax.prototype={
gm(a){return A.Z(u.S)},
$ie:1,
$ia:1}
J.bl.prototype={
gm(a){return A.Z(u.i)},
$ie:1}
J.a7.prototype={
ao(a){var t,s,r,q=a.trim(),p=q.length
if(p===0)return q
if(q.charCodeAt(0)===133){t=J.eQ(q,1)
if(t===p)return""}else t=0
s=p-1
r=q.charCodeAt(s)===133?J.eR(q,s):p
if(t===0&&r===p)return q
return q.substring(t,r)},
h(a){return a},
gp(a){var t,s,r
for(t=a.length,s=0,r=0;r<t;++r){s=s+a.charCodeAt(r)&536870911
s=s+((s&524287)<<10)&536870911
s^=s>>6}s=s+((s&67108863)<<3)&536870911
s^=s>>11
return s+((s&16383)<<15)&536870911},
gm(a){return A.Z(u.N)},
$ie:1,
$ix:1}
A.aC.prototype={
h(a){return"LateInitializationError: "+this.a}}
A.at.prototype={}
A.K.prototype={
gq(a){return new A.a9(this,this.gu(0),this.$ti.i("a9<K.E>"))}}
A.a9.prototype={
gl(){var t=this.d
return t==null?this.$ti.c.a(t):t},
k(){var t,s=this,r=s.a,q=J.ec(r),p=q.gu(r)
if(s.b!==p)throw A.i(A.ar(r))
t=s.c
if(t>=p){s.d=null
return!1}s.d=q.F(r,t);++s.c
return!0}}
A.S.prototype={
gu(a){return J.ez(this.a)},
F(a,b){return this.b.$1(J.ey(this.a,b))}}
A.A.prototype={
gq(a){return new A.bT(J.c2(this.a),this.b)}}
A.bT.prototype={
k(){var t,s
for(t=this.a,s=this.b;t.k();)if(s.$1(t.gl()))return!0
return!1},
gl(){return this.a.gl()}}
A.av.prototype={}
A.b8.prototype={
h(a){return A.da(this)},
gK(){return new A.ag(this.ai(),A.ah(this).i("ag<D<1,2>>"))},
ai(){var t=this
return function(){var s=0,r=1,q=[],p,o,n
return function $async$gK(a,b,c){if(b===1){q.push(c)
s=r}for(;;)switch(s){case 0:p=t.gan(),p=p.gq(p),o=A.ah(t).i("D<1,2>")
case 2:if(!p.k()){s=3
break}n=p.gl()
s=4
return a.b=new A.D(n,t.Z(0,n),o),1
case 4:s=2
break
case 3:return 0
case 1:return a.c=q.at(-1),3}}}}}
A.as.prototype={
gS(){var t=this.$keys
if(t==null){t=Object.keys(this.a)
this.$keys=t}return t},
ag(a){if(typeof a!="string")return!1
if("__proto__"===a)return!1
return this.a.hasOwnProperty(a)},
Z(a,b){if(!this.ag(b))return null
return this.b[this.a[b]]},
L(a,b){var t,s,r=this.gS(),q=this.b
for(t=r.length,s=0;s<t;++s)b.$2(r[s],q[s])},
gan(){return new A.aQ(this.gS(),this.$ti.i("aQ<1>"))}}
A.aQ.prototype={
gq(a){var t=this.a
return new A.bW(t,t.length,this.$ti.i("bW<1>"))}}
A.bW.prototype={
gl(){var t=this.d
return t==null?this.$ti.c.a(t):t},
k(){var t=this,s=t.c
if(s>=t.b){t.d=null
return!1}t.d=t.a[s]
t.c=s+1
return!0}}
A.aJ.prototype={}
A.ce.prototype={
t(a){var t,s,r=this,q=new RegExp(r.a).exec(a)
if(q==null)return null
t=Object.create(null)
s=r.b
if(s!==-1)t.arguments=q[s+1]
s=r.c
if(s!==-1)t.argumentsExpr=q[s+1]
s=r.d
if(s!==-1)t.expr=q[s+1]
s=r.e
if(s!==-1)t.method=q[s+1]
s=r.f
if(s!==-1)t.receiver=q[s+1]
return t}}
A.aI.prototype={
h(a){return"Null check operator used on a null value"}}
A.bn.prototype={
h(a){var t,s=this,r="NoSuchMethodError: method not found: '",q=s.b
if(q==null)return"NoSuchMethodError: "+s.a
t=s.c
if(t==null)return r+q+"' ("+s.a+")"
return r+q+"' on '"+t+"' ("+s.a+")"}}
A.bR.prototype={
h(a){var t=this.a
return t.length===0?"Error":"Error: "+t}}
A.cb.prototype={
h(a){return"Throw of null ('"+(this.a===null?"null":"undefined")+"' from JavaScript)"}}
A.bb.prototype={}
A.bY.prototype={
h(a){var t,s=this.b
if(s!=null)return s
s=this.a
t=s!==null&&typeof s==="object"?s.stack:null
return this.b=t==null?"":t}}
A.G.prototype={
h(a){var t=this.constructor,s=t==null?null:t.name
return"Closure '"+A.ek(s==null?"unknown":s)+"'"},
$iQ:1,
gaq(){return this},
$C:"$1",
$R:1,
$D:null}
A.b5.prototype={$C:"$0",$R:0}
A.b6.prototype={$C:"$2",$R:2}
A.bN.prototype={}
A.bL.prototype={
h(a){var t=this.$static_name
if(t==null)return"Closure of unknown static method"
return"Closure '"+A.ek(t)+"'"}}
A.a3.prototype={
C(a,b){if(b==null)return!1
if(this===b)return!0
if(!(b instanceof A.a3))return!1
return this.$_target===b.$_target&&this.a===b.a},
gp(a){return(A.hg(this.a)^A.bD(this.$_target))>>>0},
h(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.bE(this.a)+"'")}}
A.bF.prototype={
h(a){return"RuntimeError: "+this.a}}
A.C.prototype={
gK(){return new A.R(this,A.ah(this).i("R<1,2>"))},
E(a,b){b.L(0,new A.c8(this))},
v(a,b,c){var t,s,r=this
if(typeof b=="string"){t=r.b
r.N(t==null?r.b=r.H():t,b,c)}else if(typeof b=="number"&&(b&0x3fffffff)===b){s=r.c
r.N(s==null?r.c=r.H():s,b,c)}else r.al(b,c)},
al(a,b){var t,s,r,q=this,p=q.d
if(p==null)p=q.d=q.H()
t=q.aj(a)
s=p[t]
if(s==null)p[t]=[q.G(a,b)]
else{r=q.ak(s,a)
if(r>=0)s[r].b=b
else s.push(q.G(a,b))}},
L(a,b){var t=this,s=t.e,r=t.r
while(s!=null){b.$2(s.a,s.b)
if(r!==t.r)throw A.i(A.ar(t))
s=s.c}},
N(a,b,c){var t=a[b]
if(t==null)a[b]=this.G(b,c)
else t.b=c},
a3(){this.r=this.r+1&1073741823},
G(a,b){var t,s=this,r=new A.c9(a,b)
if(s.e==null)s.e=s.f=r
else{t=s.f
t.toString
r.d=t
s.f=t.c=r}++s.a
s.a3()
return r},
aj(a){return J.c1(a)&1073741823},
ak(a,b){var t,s
if(a==null)return-1
t=a.length
for(s=0;s<t;++s)if(J.d6(a[s].a,b))return s
return-1},
h(a){return A.da(this)},
H(){var t=Object.create(null)
t["<non-identifier-key>"]=t
delete t["<non-identifier-key>"]
return t}}
A.c8.prototype={
$2(a,b){this.a.v(0,a,b)},
$S(){return A.ah(this.a).i("~(1,2)")}}
A.c9.prototype={}
A.R.prototype={
gq(a){var t=this.a
return new A.bo(t,t.r,t.e,this.$ti.i("bo<1,2>"))}}
A.bo.prototype={
gl(){var t=this.d
t.toString
return t},
k(){var t,s=this,r=s.a
if(s.b!==r.r)throw A.i(A.ar(r))
t=s.c
if(t==null){s.d=null
return!1}else{s.d=new A.D(t.a,t.b,s.$ti.i("D<1,2>"))
s.c=t.c
return!0}}}
A.cD.prototype={
$1(a){return this.a(a)},
$S:7}
A.cE.prototype={
$2(a,b){return this.a(a,b)},
$S:8}
A.cF.prototype={
$1(a){return this.a(a)},
$S:9}
A.aa.prototype={
gm(a){return B.K},
$ie:1}
A.aG.prototype={}
A.bs.prototype={
gm(a){return B.L},
$ie:1}
A.ab.prototype={
gu(a){return a.length},
$iv:1}
A.aE.prototype={$ic:1}
A.aF.prototype={$ic:1}
A.bt.prototype={
gm(a){return B.M},
$ie:1}
A.bu.prototype={
gm(a){return B.N},
$ie:1}
A.bv.prototype={
gm(a){return B.O},
$ie:1}
A.bw.prototype={
gm(a){return B.P},
$ie:1}
A.bx.prototype={
gm(a){return B.Q},
$ie:1}
A.by.prototype={
gm(a){return B.R},
$ie:1}
A.bz.prototype={
gm(a){return B.S},
$ie:1}
A.aH.prototype={
gm(a){return B.T},
gu(a){return a.length},
$ie:1}
A.bA.prototype={
gm(a){return B.U},
gu(a){return a.length},
$ie:1}
A.aS.prototype={}
A.aT.prototype={}
A.aU.prototype={}
A.aV.prototype={}
A.z.prototype={
i(a){return A.cn(v.typeUniverse,this,a)},
B(a){return A.fg(v.typeUniverse,this,a)}}
A.bV.prototype={}
A.cl.prototype={
h(a){return A.w(this.a,null)}}
A.bU.prototype={
h(a){return this.a}}
A.aX.prototype={}
A.bZ.prototype={
gl(){return this.b},
aa(a,b){var t,s,r
a=a
b=b
t=this.a
for(;;)try{s=t(this,a,b)
return s}catch(r){b=r
a=1}},
k(){var t,s,r,q,p=this,o=null,n=0
for(;;){t=p.d
if(t!=null)try{if(t.k()){p.b=t.gl()
return!0}else p.d=null}catch(s){o=s
n=1
p.d=null}r=p.aa(n,o)
if(1===r)return!0
if(0===r){p.b=null
q=p.e
if(q==null||q.length===0){p.a=A.dQ
return!1}p.a=q.pop()
n=0
o=null
continue}if(2===r){n=0
o=null
continue}if(3===r){o=p.c
p.c=null
q=p.e
if(q==null||q.length===0){p.b=null
p.a=A.dQ
throw o
return!1}p.a=q.pop()
n=1
continue}throw A.i(A.dH("sync*"))}return!1},
ar(a){var t,s,r=this
if(a instanceof A.ag){t=a.a()
s=r.e
if(s==null)s=r.e=[]
s.push(r.a)
r.a=t
return 2}else{r.d=J.c2(a)
return 2}}}
A.ag.prototype={
gq(a){return new A.bZ(this.a())}}
A.aR.prototype={
gq(a){var t=this,s=new A.af(t,t.r,t.$ti.i("af<1>"))
s.c=t.e
return s},
ae(a,b){var t,s,r=this
if(typeof b=="string"&&b!=="__proto__"){t=r.b
return r.O(t==null?r.b=A.dc():t,b)}else if(typeof b=="number"&&(b&1073741823)===b){s=r.c
return r.O(s==null?r.c=A.dc():s,b)}else return r.a4(b)},
a4(a){var t,s,r=this,q=r.d
if(q==null)q=r.d=A.dc()
t=J.c1(a)&1073741823
s=q[t]
if(s==null)q[t]=[r.I(a)]
else{if(r.a9(s,a)>=0)return!1
s.push(r.I(a))}return!0},
O(a,b){if(a[b]!=null)return!1
a[b]=this.I(b)
return!0},
T(){this.r=this.r+1&1073741823},
I(a){var t,s=this,r=new A.cj(a)
if(s.e==null)s.e=s.f=r
else{t=s.f
t.toString
r.c=t
s.f=t.b=r}++s.a
s.T()
return r},
a9(a,b){var t,s
if(a==null)return-1
t=a.length
for(s=0;s<t;++s)if(J.d6(a[s].a,b))return s
return-1}}
A.cj.prototype={}
A.af.prototype={
gl(){var t=this.d
return t==null?this.$ti.c.a(t):t},
k(){var t=this,s=t.c,r=t.a
if(t.b!==r.r)throw A.i(A.ar(r))
else if(s==null){t.d=null
return!1}else{t.d=s.a
t.c=s.b
return!0}}}
A.f.prototype={
gq(a){return new A.a9(a,a.length,A.al(a).i("a9<f.E>"))},
F(a,b){return a[b]},
Y(a,b,c){return new A.S(a,b,A.al(a).i("@<f.E>").B(c).i("S<1,2>"))},
h(a){return A.d7(a,"[","]")}}
A.br.prototype={
h(a){return A.da(this)}}
A.ca.prototype={
$2(a,b){var t,s=this.a
if(!s.a)this.b.a+=", "
s.a=!1
s=this.b
t=A.n(a)
s.a=(s.a+=t)+": "
t=A.n(b)
s.a+=t},
$S:10}
A.aK.prototype={
h(a){return A.d7(this,"{","}")}}
A.aW.prototype={}
A.cg.prototype={
h(a){return this.a6()}}
A.j.prototype={}
A.b3.prototype={
h(a){var t=this.a
if(t!=null)return"Assertion failed: "+A.c5(t)
return"Assertion failed"}}
A.aO.prototype={}
A.ao.prototype={
ga8(){return"Invalid argument"+(!this.a?"(s)":"")},
ga7(){return""},
h(a){var t=this,s=t.c,r=s==null?"":" ("+s+")",q=t.d,p=q==null?"":": "+q,o=t.ga8()+r+p
if(!t.a)return o
return o+t.ga7()+": "+A.c5(t.gam())},
gam(){return this.b}}
A.bS.prototype={
h(a){return"Unsupported operation: "+this.a}}
A.bQ.prototype={
h(a){return"UnimplementedError: "+this.a}}
A.bK.prototype={
h(a){return"Bad state: "+this.a}}
A.b7.prototype={
h(a){var t=this.a
if(t==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.c5(t)+"."}}
A.aN.prototype={
h(a){return"Stack Overflow"},
$ij:1}
A.ch.prototype={
h(a){return"Exception: "+this.a}}
A.o.prototype={
gu(a){var t,s=this.gq(this)
for(t=0;s.k();)++t
return t},
h(a){return A.eP(this,"(",")")}}
A.D.prototype={
h(a){return"MapEntry("+A.n(this.a)+": "+A.n(this.b)+")"}}
A.T.prototype={
gp(a){return A.k.prototype.gp.call(this,0)},
h(a){return"null"}}
A.k.prototype={$ik:1,
C(a,b){return this===b},
gp(a){return A.bD(this)},
h(a){return"Instance of '"+A.bE(this)+"'"},
gm(a){return A.ed(this)},
toString(){return this.h(this)}}
A.bM.prototype={
h(a){var t=this.a
return t.charCodeAt(0)==0?t:t}}
A.a2.prototype={}
A.b.prototype={}
A.bO.prototype={}
A.au.prototype={}
A.H.prototype={}
A.bq.prototype={}
A.bH.prototype={}
A.aw.prototype={
af(){var t=J.eB(this.a.$0(),new A.c6(this),u.c)
t=A.aD(t,t.$ti.i("K.E"))
return t}}
A.c6.prototype={
$1(a){return this.a.b.$1(a)},
$S(){return this.a.$ti.i("b(1)")}}
A.M.prototype={}
A.L.prototype={}
A.aL.prototype={}
A.a6.prototype={}
A.b9.prototype={}
A.ae.prototype={}
A.ac.prototype={}
A.be.prototype={}
A.bf.prototype={}
A.a4.prototype={}
A.bh.prototype={}
A.bP.prototype={}
A.a8.prototype={}
A.bd.prototype={}
A.bg.prototype={}
A.bc.prototype={}
A.bG.prototype={}
A.c3.prototype={}
A.bX.prototype={
X(){var t,s,r,q,p,o
for(s=this.a,r=A.dM(s,s.r,s.$ti.c),q=r.$ti.c;r.k();){p=r.d
t=p==null?q.a(p):p
try{t.$0()}catch(o){}}if(s.a>0){s.b=s.c=s.d=s.e=s.f=null
s.a=0
s.T()}}}
A.cx.prototype={
$0(){var t=this.a
if(this.b.a.$0())t=t.b
else{t=t.a
if(t==null)t=new A.H(B.a)}return t},
$S:11}
A.cy.prototype={
$0(){return this.a.af()},
$S:12}
A.cz.prototype={
$1(a){return new A.H(a)},
$S:13}
A.ct.prototype={
$0(){var t,s,r,q,p=this,o=p.a
o.X()
t=p.b.$0()
s=p.c
r=A.cw(s==null?u.c.a(t):s.$1(t),o)
o=p.d
o.textContent=""
for(s=r.length,q=0;q<r.length;r.length===s||(0,A.an)(r),++q)o.appendChild(r[q])},
$S:1}
A.cs.prototype={
$0(){this.a.$0()},
$S:14}
A.cr.prototype={
$0(){this.a.$0()
this.b.X()},
$S:1}
A.cp.prototype={
$1(a){var t=A.h1(this.a,a)
this.b.$1(t)
if(t.r)a.preventDefault()},
$S:15}
A.cA.prototype={
$0(){return this.a.preventDefault()},
$S:1}
A.aq.prototype={
J(){var t,s,r,q,p,o,n,m=this,l=m.at&=4294967293
if((l&1)!==0)return!1
if((l&36)===32)return!0
l&=4294967291
m.at=l
q=m.as
p=$.cv
if(q===p)return!0
m.as=p
m.at=l|1
t=A.e7(m)
if(m.e>0&&!t){m.at&=4294967294
return!0}o=$.t
try{A.e8(m)
$.t=m
s=m.z.$0()
if((m.at&16)!==0||t||m.e===0){if(m.e!==0){l=m.y
l===$&&A.a1()
l=!J.d6(s,l)}else l=!0
if(l){l=m.e
if(l!==0)m.y===$&&A.a1()
m.y=s
m.at&=4294967279
m.e=l+1}}}catch(n){r=A.el(n)
m.ax=r
m.at|=16;++m.e}$.t=o
A.e1(m)
m.at&=4294967294
return!0},
D(a){var t,s=this
if(s.r==null){s.at|=36
for(t=s.Q;t!=null;t=t.c)t.a.D(t)}s.a1(a)},
A(a){var t=this
if(t.r!=null){t.M(a)
if(t.r==null){t.at&=4294967263
for(a=t.Q;a!=null;a=a.c)a.a.A(a)}}},
U(){var t=this.at
if((t&2)===0){this.at=t|6
this.V()}},
gj(){var t,s,r=this
if(r.b){A.eh("computed warning: ["+r.d+"|"+A.n(r.c)+"] has been read after disposed: "+A.dG().h(0))
t=r.y
t===$&&A.a1()
return t}if((r.at&1)!==0)throw A.i(new A.a5())
s=A.dX(r)
r.J()
if(s!=null)s.r=r.e
if((r.at&16)!==0){t=r.ax
t.toString
throw A.i(t)}t=r.y
t===$&&A.a1()
return t},
gn(){return this.Q},
gR(){return this.at},
sn(a){return this.Q=a}}
A.ba.prototype={
a2(a,b){var t
try{this.P()}catch(t){this.W()
throw t}},
P(){var t,s,r=this,q=r.ad()
try{if((r.r&8)!==0)return
s=r.a
if(s==null)return
t=s.$0()
if(u.Z.b(t))r.d=t}finally{q.$0()}},
ad(){var t,s=this,r=s.r
if((r&1)!==0)throw A.i(new A.a5())
r|=1
s.r=r
s.r=r&4294967287
A.e0(s)
A.e8(s)
$.F=$.F+1
t=$.t
$.t=s
return new A.c4(s,t)},
U(){var t=this,s=t.r
if((s&2)===0){t.r=s|2
t.f=$.cq
$.cq=t}},
W(){var t,s,r,q=this
if(q.x)return
if(((q.r|=8)&1)===0)A.dg(q)
for(t=q.w,t=A.dM(t,t.r,t.$ti.c),s=t.$ti.c;t.k();){r=t.d;(r==null?s.a(r):r).$0()}q.x=!0},
gn(){return this.e},
gR(){return this.r},
sn(a){return this.e=a}}
A.c4.prototype={
$0(){var t=this.a
if($.t!==t)A.c0(A.eJ("Out-of-order effect"))
A.e1(t)
$.t=this.b
if(((t.r&=4294967294)&8)!==0)A.dg(t)
A.dh()
return null},
$S:1}
A.ad.prototype={
V(){for(var t=this.r;t!=null;t=t.f)t.d.U()},
h(a){return A.n(this.gj())},
$0(){return this.gj()},
D(a){var t=this.r
if(t!==a&&a.e==null){a.f=t
if(t!=null)t.e=a
this.r=a}},
A(a){var t,s,r=this.r
if(r!=null){t=a.e
s=a.f
if(t!=null){t.f=s
a.e=null}if(s!=null){s.e=t
a.f=null}if(a===r)this.r=s}}}
A.aM.prototype={
J(){return!0},
A(a){this.M(a)},
a_(a){var t=this,s=t.Q
s===$&&A.a1()
s=t.as.$2(a,s)
if(s)return!1
if($.cu>100)throw A.i(new A.a5())
s=t.Q
s===$&&A.a1()
if(a!==s)t.Q=a;++t.e
$.cv=$.cv+1
$.F=$.F+1
try{t.V()}finally{A.dh()}return!0},
sj(a){if(this.b)throw A.i(new A.bJ("A "+A.ed(this).h(0)+" signal was written after being disposed.\nOnce you have called dispose() on a signal, it can no longer be used."))
this.a_(a)},
gj(){var t,s,r=this
if(r.b){A.eh("signal warning: ["+r.d+"|"+A.n(r.c)+"] has been read after disposed: "+A.dG().h(0))
t=r.Q
t===$&&A.a1()
return t}s=A.dX(r)
if(s!=null)s.r=r.e
t=r.Q
t===$&&A.a1()
return t}}
A.cc.prototype={
$2(a,b){return a===b},
$S(){return this.a.i("ak(0,0)")}}
A.ck.prototype={}
A.bI.prototype={
h(a){return this.a}}
A.bJ.prototype={}
A.a5.prototype={}
A.r.prototype={}
A.U.prototype={
a6(){return"TodoFilter."+this.b}}
A.cO.prototype={
$0(){return this.a.gj()*2},
$S:3}
A.cP.prototype={
$0(){var t,s,r=this
switch(r.a.gj().a){case 0:return r.b.gj()
case 1:t=r.b.gj()
s=A.W(t).i("A<1>")
t=A.aD(new A.A(t,new A.cL(),s),s.i("o.E"))
return t
case 2:t=r.b.gj()
s=A.W(t).i("A<1>")
t=A.aD(new A.A(t,new A.cM(),s),s.i("o.E"))
return t}},
$S:4}
A.cL.prototype={
$1(a){return!a.c},
$S:2}
A.cM.prototype={
$1(a){return a.c},
$S:2}
A.cQ.prototype={
$0(){var t=this.a.gj()
return new A.A(t,new A.cK(),A.W(t).i("A<1>")).gu(0)},
$S:3}
A.cK.prototype={
$1(a){return!a.c},
$S:2}
A.cN.prototype={
$1(a){var t,s,r,q
a.r=!0
a.e.$0()
t=this.a
s=B.q.ao(t.gj())
if(s.length===0)return
r=this.b
q=A.aD(r.gj(),u.J)
q.push(new A.r(B.e.h(Date.now()),s,!1))
r.sj(q)
t.sj("")},
$S:0}
A.d3.prototype={
$1(a){var t,s,r,q,p,o=this.a,n=A.d([],u.V)
for(t=o.gj(),s=t.length,r=0;r<t.length;t.length===s||(0,A.an)(t),++r){q=t[r]
p=q.a
if(p===a)n.push(new A.r(p,q.b,!q.c))
else n.push(q)}o.sj(n)},
$S:5}
A.d1.prototype={
$1(a){var t=this.a,s=t.gj(),r=A.W(s).i("A<1>")
s=A.aD(new A.A(s,new A.d2(a),r),r.i("o.E"))
t.sj(s)},
$S:5}
A.d2.prototype={
$1(a){return a.a!==this.a},
$S:2}
A.cU.prototype={
$0(){return A.bB("text-2xl font-bold text-zinc-100 font-mono",""+this.a.gj())},
$S:6}
A.cV.prototype={
$0(){return A.bB("text-2xl font-bold text-indigo-400 font-mono",""+this.a.gj())},
$S:6}
A.cW.prototype={
$1(a){var t=this.a,s=t.gj()
t.sj(s-1)
return s},
$S:0}
A.cX.prototype={
$1(a){var t=this.a,s=t.gj()
t.sj(s+1)
return s},
$S:0}
A.cY.prototype={
$1(a){this.a.sj(0)
return 0},
$S:0}
A.cZ.prototype={
$0(){return this.a.gj()>=10},
$S:16}
A.d_.prototype={
$0(){return A.cd("text-xs text-zinc-400 font-mono",""+this.a.gj()+" pending")},
$S:17}
A.d0.prototype={
$1(a){var t=a.b
if(t==null)t=""
this.a.sj(t)
return t},
$S:0}
A.cR.prototype={
$0(){var t=this.a,s=this.b
return A.ap(null,"px-2.5 py-1 text-xs font-mono rounded cursor-pointer "+(t.gj()===s?"bg-indigo-600/20 text-indigo-400 border border-indigo-500/30":"text-zinc-500 hover:text-zinc-300"),new A.cJ(t,s),s.b.toUpperCase())},
$S:18}
A.cJ.prototype={
$1(a){var t=this.b
this.a.sj(t)
return t},
$S:0}
A.cS.prototype={
$0(){return this.a.gj()},
$S:4}
A.cT.prototype={
$1(a){var t=null,s=u.t
s=A.d([A.u(A.d([A.cd("text-sm "+(a.c?"line-through text-zinc-500":"text-zinc-200"),a.b)],s),"flex items-center space-x-3 cursor-pointer",new A.cH(this.a,a)),A.ap(t,"text-xs text-zinc-500 hover:text-red-400 cursor-pointer px-2 py-1",new A.cI(this.b,a),"Delete")],s)
return new A.a8("li",t,"flex items-center justify-between p-3 bg-[#09090B] border border-[#1E1E24] hover:border-[#27272A] rounded-lg transition-colors",t,t,A.O(t,t,t,t,t,t,t),s)},
$S:19}
A.cH.prototype={
$1(a){return this.a.$1(this.b.a)},
$S:0}
A.cI.prototype={
$1(a){return this.a.$1(this.b.a)},
$S:0};(function aliases(){var t=J.J.prototype
t.a0=t.h
t=A.ad.prototype
t.a1=t.D
t.M=t.A})();(function installTearOffs(){var t=hunkHelpers._instance_0u
t(A.ba.prototype,"gah","W",1)})();(function inheritance(){var t=hunkHelpers.mixin,s=hunkHelpers.inherit,r=hunkHelpers.inheritMany
s(A.k,null)
r(A.k,[A.d8,J.bi,A.aJ,J.b2,A.j,A.o,A.a9,A.bT,A.av,A.b8,A.bW,A.ce,A.cb,A.bb,A.bY,A.G,A.br,A.c9,A.bo,A.z,A.bV,A.cl,A.bZ,A.aK,A.cj,A.af,A.f,A.cg,A.aN,A.ch,A.D,A.T,A.bM,A.a2,A.b,A.c3,A.bX,A.ad,A.ba,A.ck,A.r])
r(J.bi,[J.bk,J.ay,J.aA,J.az,J.aB,J.bm,J.a7])
r(J.aA,[J.J,J.m,A.aa,A.aG])
r(J.J,[J.bC,J.aP,J.I])
s(J.bj,A.aJ)
s(J.c7,J.m)
r(J.bm,[J.ax,J.bl])
r(A.j,[A.aC,A.aO,A.bn,A.bR,A.bF,A.bU,A.b3,A.ao,A.bS,A.bQ,A.bK,A.b7,A.bI,A.a5])
r(A.o,[A.at,A.A,A.aQ,A.ag])
r(A.at,[A.K,A.R])
s(A.S,A.K)
s(A.as,A.b8)
s(A.aI,A.aO)
r(A.G,[A.b5,A.b6,A.bN,A.cD,A.cF,A.c6,A.cz,A.cp,A.cL,A.cM,A.cK,A.cN,A.d3,A.d1,A.d2,A.cW,A.cX,A.cY,A.d0,A.cJ,A.cT,A.cH,A.cI])
r(A.bN,[A.bL,A.a3])
s(A.C,A.br)
r(A.b6,[A.c8,A.cE,A.ca,A.cc])
r(A.aG,[A.bs,A.ab])
r(A.ab,[A.aS,A.aU])
s(A.aT,A.aS)
s(A.aE,A.aT)
s(A.aV,A.aU)
s(A.aF,A.aV)
r(A.aE,[A.bt,A.bu])
r(A.aF,[A.bv,A.bw,A.bx,A.by,A.bz,A.aH,A.bA])
s(A.aX,A.bU)
s(A.aW,A.aK)
s(A.aR,A.aW)
r(A.b,[A.bO,A.au,A.H,A.bq,A.bH,A.aw])
s(A.M,A.bO)
s(A.L,A.bq)
s(A.aL,A.bH)
s(A.a6,A.aw)
r(A.au,[A.b9,A.ae,A.ac,A.be,A.bf,A.a4,A.bh,A.bP,A.a8,A.bd,A.bg,A.bc,A.bG])
r(A.b5,[A.cx,A.cy,A.ct,A.cs,A.cr,A.cA,A.c4,A.cO,A.cP,A.cQ,A.cU,A.cV,A.cZ,A.d_,A.cR,A.cS])
r(A.ad,[A.aq,A.aM])
s(A.bJ,A.bI)
s(A.U,A.cg)
t(A.aS,A.f)
t(A.aT,A.av)
t(A.aU,A.f)
t(A.aV,A.av)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{a:"int",p:"double",ef:"num",x:"String",ak:"bool",T:"Null",c:"List",k:"Object",hq:"Map",h:"JSObject"},mangledNames:{},types:["~(a2)","~()","ak(r)","a()","c<r>()","~(x)","ac()","@(@)","@(@,x)","@(x)","~(k?,k?)","b()","c<b>()","H(c<b>)","T()","~(h)","ak()","ae()","a4()","a8(r)"],interceptorsByTag:null,leafTags:null,arrayRti:Symbol("$ti")}
A.ff(v.typeUniverse,JSON.parse('{"bC":"J","aP":"J","I":"J","hr":"aa","bk":{"e":[]},"ay":{"e":[]},"aA":{"h":[]},"J":{"h":[]},"m":{"c":["1"],"h":[]},"bj":{"aJ":[]},"c7":{"m":["1"],"c":["1"],"h":[]},"bm":{"p":[]},"ax":{"p":[],"a":[],"e":[]},"bl":{"p":[],"e":[]},"a7":{"x":[],"e":[]},"aC":{"j":[]},"at":{"o":["1"]},"K":{"o":["1"]},"S":{"K":["2"],"o":["2"],"K.E":"2","o.E":"2"},"A":{"o":["1"],"o.E":"1"},"as":{"b8":["1","2"]},"aQ":{"o":["1"],"o.E":"1"},"aI":{"j":[]},"bn":{"j":[]},"bR":{"j":[]},"G":{"Q":[]},"b5":{"Q":[]},"b6":{"Q":[]},"bN":{"Q":[]},"bL":{"Q":[]},"a3":{"Q":[]},"bF":{"j":[]},"C":{"br":["1","2"]},"R":{"o":["D<1,2>"],"o.E":"D<1,2>"},"aa":{"h":[],"e":[]},"aG":{"h":[]},"bs":{"h":[],"e":[]},"ab":{"v":["1"],"h":[]},"aE":{"f":["p"],"c":["p"],"v":["p"],"h":[]},"aF":{"f":["a"],"c":["a"],"v":["a"],"h":[]},"bt":{"f":["p"],"c":["p"],"v":["p"],"h":[],"e":[],"f.E":"p"},"bu":{"f":["p"],"c":["p"],"v":["p"],"h":[],"e":[],"f.E":"p"},"bv":{"f":["a"],"c":["a"],"v":["a"],"h":[],"e":[],"f.E":"a"},"bw":{"f":["a"],"c":["a"],"v":["a"],"h":[],"e":[],"f.E":"a"},"bx":{"f":["a"],"c":["a"],"v":["a"],"h":[],"e":[],"f.E":"a"},"by":{"f":["a"],"c":["a"],"v":["a"],"h":[],"e":[],"f.E":"a"},"bz":{"f":["a"],"c":["a"],"v":["a"],"h":[],"e":[],"f.E":"a"},"aH":{"f":["a"],"c":["a"],"v":["a"],"h":[],"e":[],"f.E":"a"},"bA":{"f":["a"],"c":["a"],"v":["a"],"h":[],"e":[],"f.E":"a"},"bU":{"j":[]},"aX":{"j":[]},"ag":{"o":["1"],"o.E":"1"},"aR":{"aK":["1"]},"aW":{"aK":["1"]},"b3":{"j":[]},"aO":{"j":[]},"ao":{"j":[]},"bS":{"j":[]},"bQ":{"j":[]},"bK":{"j":[]},"b7":{"j":[]},"aN":{"j":[]},"H":{"b":[]},"ae":{"b":[]},"ac":{"b":[]},"a4":{"b":[]},"a8":{"b":[]},"bO":{"b":[]},"au":{"b":[]},"bq":{"b":[]},"bH":{"b":[]},"aw":{"b":[]},"M":{"b":[]},"L":{"b":[]},"aL":{"b":[]},"a6":{"aw":["1"],"b":[]},"b9":{"b":[]},"be":{"b":[]},"bf":{"b":[]},"bh":{"b":[]},"bP":{"b":[]},"bd":{"b":[]},"bg":{"b":[]},"bc":{"b":[]},"bG":{"b":[]},"aq":{"ad":["1"]},"aM":{"ad":["1"]},"bI":{"j":[]},"bJ":{"j":[]},"a5":{"j":[]},"eO":{"c":["a"]},"f0":{"c":["a"]},"f_":{"c":["a"]},"eM":{"c":["a"]},"eY":{"c":["a"]},"eN":{"c":["a"]},"eZ":{"c":["a"]},"eK":{"c":["p"]},"eL":{"c":["p"]}}'))
A.fe(v.typeUniverse,JSON.parse('{"at":1,"bT":1,"av":1,"ab":1,"bZ":1,"aW":1}'))
var u=(function rtii(){var t=A.c_
return{c:t("b"),C:t("j"),o:t("a6<r>"),Z:t("Q"),t:t("m<b>"),O:t("m<h>"),s:t("m<x>"),V:t("m<r>"),b:t("m<@>"),T:t("ay"),m:t("h"),g:t("I"),p:t("v<@>"),B:t("c<r>"),j:t("c<@>"),P:t("T"),K:t("k"),L:t("hs"),N:t("x"),U:t("U"),J:t("r"),R:t("e"),A:t("aP"),y:t("ak"),i:t("p"),S:t("a"),Q:t("dz<T>?"),z:t("h?"),X:t("k?"),v:t("x?"),u:t("ak?"),I:t("p?"),w:t("a?"),n:t("ef?"),H:t("ef"),M:t("~()"),W:t("~(a2)")}})();(function constants(){var t=hunkHelpers.makeConstList
B.o=J.bi.prototype
B.p=J.m.prototype
B.e=J.ax.prototype
B.q=J.a7.prototype
B.r=J.I.prototype
B.t=J.aA.prototype
B.f=J.bC.prototype
B.b=J.aP.prototype
B.c=function getTagFallback(o) {
  var s = Object.prototype.toString.call(o);
  return s.substring(8, s.length - 1);
}
B.i=function() {
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
B.n=function(getTagFallback) {
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
B.j=function(hooks) {
  if (typeof dartExperimentalFixupGetTag != "function") return hooks;
  hooks.getTag = dartExperimentalFixupGetTag(hooks.getTag);
}
B.m=function(hooks) {
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
B.l=function(hooks) {
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
B.k=function(hooks) {
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
B.d=function(hooks) { return hooks; }

B.D=new A.M("Double digit milestone reached.")
B.u=t([B.D],u.t)
B.E=new A.M("Increment count to 10 to test Show condition.")
B.v=t([B.E],u.t)
B.C=new A.M("Bloom Framework \u2014 Pure Dart Descriptors + Direct Browser DOM")
B.w=t([B.C],u.t)
B.h=new A.U(0,"all")
B.F=new A.U(1,"active")
B.G=new A.U(2,"completed")
B.x=t([B.h,B.F,B.G],A.c_("m<U>"))
B.B=new A.M("B")
B.y=t([B.B],u.t)
B.a=t([],u.t)
B.A={type:0}
B.z=new A.as(B.A,["submit"],A.c_("as<x,x>"))
B.H=new A.r("3","Ship Bloom JS Native M1-M3",!1)
B.I=new A.r("1","Architect pure-Dart descriptor tree",!0)
B.J=new A.r("2","Mount fine-grained DOM with signals",!0)
B.K=A.B("hm")
B.L=A.B("hn")
B.M=A.B("eK")
B.N=A.B("eL")
B.O=A.B("eM")
B.P=A.B("eN")
B.Q=A.B("eO")
B.R=A.B("eY")
B.S=A.B("eZ")
B.T=A.B("f_")
B.U=A.B("f0")})();(function staticFields(){$.ci=null
$.Y=A.d([],A.c_("m<k>"))
$.dD=null
$.dw=null
$.dv=null
$.ee=null
$.ea=null
$.ei=null
$.cB=null
$.cG=null
$.dp=null
$.cv=0
$.t=null
$.cq=null
$.F=0
$.cu=0
$.b0=0})();(function lazyInitializers(){var t=hunkHelpers.lazyFinal
t($,"hp","em",()=>A.cC("_$dart_dartClosure"))
t($,"ho","ds",()=>A.cC("_$dart_dartClosure_dartJSInterop"))
t($,"hD","ex",()=>A.d([new J.bj()],A.c_("m<aJ>")))
t($,"ht","en",()=>A.E(A.cf({
toString:function(){return"$receiver$"}})))
t($,"hu","eo",()=>A.E(A.cf({$method$:null,
toString:function(){return"$receiver$"}})))
t($,"hv","ep",()=>A.E(A.cf(null)))
t($,"hw","eq",()=>A.E(function(){var $argumentsExpr$="$arguments$"
try{null.$method$($argumentsExpr$)}catch(s){return s.message}}()))
t($,"hz","et",()=>A.E(A.cf(void 0)))
t($,"hA","eu",()=>A.E(function(){var $argumentsExpr$="$arguments$"
try{(void 0).$method$($argumentsExpr$)}catch(s){return s.message}}()))
t($,"hy","es",()=>A.E(A.dJ(null)))
t($,"hx","er",()=>A.E(function(){try{null.$method$}catch(s){return s.message}}()))
t($,"hC","ew",()=>A.E(A.dJ(void 0)))
t($,"hB","ev",()=>A.E(function(){try{(void 0).$method$}catch(s){return s.message}}()))})();(function nativeSupport(){!function(){var t=function(a){var n={}
n[a]=1
return Object.keys(hunkHelpers.convertToFastObject(n))[0]}
v.getIsolateTag=function(a){return t("___dart_"+a+v.isolateTag)}
var s="___dart_isolate_tags_"
var r=Object[s]||(Object[s]=Object.create(null))
var q="_ZxYxX"
for(var p=0;;p++){var o=t(q+"_"+p+"_")
if(!(o in r)){r[o]=1
v.isolateTag=o
break}}v.dispatchPropertyName=v.getIsolateTag("dispatch_record")}()
hunkHelpers.setOrUpdateInterceptorsByTag({ArrayBuffer:A.aa,SharedArrayBuffer:A.aa,ArrayBufferView:A.aG,DataView:A.bs,Float32Array:A.bt,Float64Array:A.bu,Int16Array:A.bv,Int32Array:A.bw,Int8Array:A.bx,Uint16Array:A.by,Uint32Array:A.bz,Uint8ClampedArray:A.aH,CanvasPixelArray:A.aH,Uint8Array:A.bA})
hunkHelpers.setOrUpdateLeafTags({ArrayBuffer:true,SharedArrayBuffer:true,ArrayBufferView:false,DataView:true,Float32Array:true,Float64Array:true,Int16Array:true,Int32Array:true,Int8Array:true,Uint16Array:true,Uint32Array:true,Uint8ClampedArray:true,CanvasPixelArray:true,Uint8Array:false})
A.ab.$nativeSuperclassTag="ArrayBufferView"
A.aS.$nativeSuperclassTag="ArrayBufferView"
A.aT.$nativeSuperclassTag="ArrayBufferView"
A.aE.$nativeSuperclassTag="ArrayBufferView"
A.aU.$nativeSuperclassTag="ArrayBufferView"
A.aV.$nativeSuperclassTag="ArrayBufferView"
A.aF.$nativeSuperclassTag="ArrayBufferView"})()
Function.prototype.$1=function(a){return this(a)}
Function.prototype.$2=function(a,b){return this(a,b)}
Function.prototype.$0=function(){return this()}
Function.prototype.$1$1=function(a){return this(a)}
convertAllToFastObject(w)
convertToFastObject($);(function(a){if(typeof document==="undefined"){a(null)
return}if(typeof document.currentScript!="undefined"){a(document.currentScript)
return}var t=document.scripts
function onLoad(b){for(var r=0;r<t.length;++r){t[r].removeEventListener("load",onLoad,false)}a(b.target)}for(var s=0;s<t.length;++s){t[s].addEventListener("load",onLoad,false)}})(function(a){v.currentScript=a
var t=A.hd
if(typeof dartMainRunner==="function"){dartMainRunner(t,[])}else{t([])}})})()
//# sourceMappingURL=main.js.map
