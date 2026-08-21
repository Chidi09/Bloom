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
if(a[b]!==s){A.jZ(b)}a[b]=r}var q=a[b]
a[c]=function(){return q}
return q}}function makeConstList(a,b){if(b!=null)A.b(a,b)
a.$flags=7
return a}function convertToFastObject(a){function t(){}t.prototype=a
new t()
return a}function convertAllToFastObject(a){for(var s=0;s<a.length;++s){convertToFastObject(a[s])}}var y=0
function instanceTearOffGetter(a,b){var s=null
return a?function(c){if(s===null)s=A.fn(b)
return new s(c,this)}:function(){if(s===null)s=A.fn(b)
return new s(this,null)}}function staticTearOffGetter(a){var s=null
return function(){if(s===null)s=A.fn(a).prototype
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
fs(a,b,c,d){return{i:a,p:b,e:c,x:d}},
fp(a){var s,r,q,p,o,n="_$dart_js",m=a[v.dispatchPropertyName]
if(m==null)if($.fq==null){A.jP()
m=a[v.dispatchPropertyName]}if(m!=null){s=m.p
if(!1===s)return m.i
if(!0===s)return a
r=Object.getPrototypeOf(a)
if(s===r)return m.i
if(m.e===r)throw A.f(A.fO("Return interceptor for "+A.o(s(a,m))))}q=a.constructor
if(q==null)p=null
else{o=$.eo
if(o==null)o=$.eo=A.eS(n)
p=q[o]}if(p!=null)return p
p=A.jT(a)
if(p!=null)return p
if(typeof a=="function")return B.A
s=Object.getPrototypeOf(a)
if(s==null)return B.n
if(s===Object.prototype)return B.n
if(typeof q=="function"){o=$.eo
if(o==null)o=$.eo=A.eS(n)
Object.defineProperty(q,o,{value:B.i,enumerable:false,writable:true,configurable:true})
return B.i}return B.i},
i1(a,b){if(a<0||a>4294967295)throw A.f(A.dR(a,0,4294967295,"length",null))
return J.i3(new Array(a),b)},
i2(a,b){if(a<0)throw A.f(A.aQ("Length must be a non-negative integer: "+a,null))
return A.b(new Array(a),b.i("t<0>"))},
dE(a,b){if(a<0)throw A.f(A.aQ("Length must be a non-negative integer: "+a,null))
return A.b(new Array(a),b.i("t<0>"))},
i3(a,b){var s=A.b(a,b.i("t<0>"))
s.$flags=1
return s},
fF(a){if(a<256)switch(a){case 9:case 10:case 11:case 12:case 13:case 32:case 133:case 160:return!0
default:return!1}switch(a){case 5760:case 8192:case 8193:case 8194:case 8195:case 8196:case 8197:case 8198:case 8199:case 8200:case 8201:case 8202:case 8232:case 8233:case 8239:case 8287:case 12288:case 65279:return!0
default:return!1}},
i4(a,b){var s,r
for(s=a.length;b<s;){r=a.charCodeAt(b)
if(r!==32&&r!==13&&!J.fF(r))break;++b}return b},
i5(a,b){var s,r
for(;b>0;b=s){s=b-1
r=a.charCodeAt(s)
if(r!==32&&r!==13&&!J.fF(r))break}return b},
am(a){if(typeof a=="number"){if(Math.floor(a)==a)return J.aX.prototype
return J.bU.prototype}if(typeof a=="string")return J.az.prototype
if(a==null)return J.aY.prototype
if(typeof a=="boolean")return J.bT.prototype
if(Array.isArray(a))return J.t.prototype
if(typeof a!="object"){if(typeof a=="function")return J.Z.prototype
if(typeof a=="symbol")return J.b1.prototype
if(typeof a=="bigint")return J.b_.prototype
return a}if(a instanceof A.j)return a
return J.fp(a)},
hq(a){if(typeof a=="string")return J.az.prototype
if(a==null)return a
if(Array.isArray(a))return J.t.prototype
if(typeof a!="object"){if(typeof a=="function")return J.Z.prototype
if(typeof a=="symbol")return J.b1.prototype
if(typeof a=="bigint")return J.b_.prototype
return a}if(a instanceof A.j)return a
return J.fp(a)},
cG(a){if(a==null)return a
if(Array.isArray(a))return J.t.prototype
if(typeof a!="object"){if(typeof a=="function")return J.Z.prototype
if(typeof a=="symbol")return J.b1.prototype
if(typeof a=="bigint")return J.b_.prototype
return a}if(a instanceof A.j)return a
return J.fp(a)},
aq(a,b){if(a==null)return b==null
if(typeof a!="object")return b!=null&&a===b
return J.am(a).F(a,b)},
cH(a,b){return J.cG(a).D(a,b)},
hN(a,b){return J.cG(a).Y(a,b)},
N(a){return J.am(a).gm(a)},
cI(a){return J.cG(a).gq(a)},
hO(a){return J.hq(a).gB(a)},
hP(a){return J.am(a).gn(a)},
cJ(a,b,c){return J.cG(a).J(a,b,c)},
bB(a){return J.am(a).j(a)},
hQ(a,b){return J.cG(a).aN(a,b)},
bR:function bR(){},
bT:function bT(){},
aY:function aY(){},
b0:function b0(){},
a_:function a_(){},
cd:function cd(){},
bb:function bb(){},
Z:function Z(){},
b_:function b_(){},
b1:function b1(){},
t:function t(a){this.$ti=a},
bS:function bS(){},
dG:function dG(a){this.$ti=a},
bD:function bD(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
aZ:function aZ(){},
aX:function aX(){},
bU:function bU(){},
az:function az(){}},A={f8:function f8(){},
i7(a){return new A.b2("Field '"+a+"' has been assigned during initialization.")},
i8(a){return new A.b2("Field '"+a+"' has not been initialized.")},
a2(a,b){a=a+b&536870911
a=a+((a&524287)<<10)&536870911
return a^a>>>6},
fc(a){a=a+((a&67108863)<<3)&536870911
a^=a>>>11
return a+((a&16383)<<15)&536870911},
hn(a,b,c){return a},
fr(a){var s,r
for(s=$.ak.length,r=0;r<s;++r)if(a===$.ak[r])return!0
return!1},
ia(a,b,c,d){if(t.W.b(a))return new A.aa(a,b,c.i("@<0>").u(d).i("aa<1,2>"))
return new A.S(a,b,c.i("@<0>").u(d).i("S<1,2>"))},
b2:function b2(a){this.a=a},
dS:function dS(){},
i:function i(){},
I:function I(){},
aB:function aB(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
S:function S(a,b,c){this.a=a
this.b=b
this.$ti=c},
aa:function aa(a,b,c){this.a=a
this.b=b
this.$ti=c},
c0:function c0(a,b,c){var _=this
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
cu:function cu(a,b){this.a=a
this.b=b},
aT:function aT(){},
hz(a){var s=A.hy(a)
if(s!=null)return s
return"minified:"+a},
kj(a,b){var s
if(b!=null){s=b.x
if(s!=null)return s}return t.p.b(a)},
o(a){var s
if(typeof a=="string")return a
if(typeof a=="number"){if(a!==0)return""+a}else if(!0===a)return"true"
else if(!1===a)return"false"
else if(a==null)return"null"
s=J.bB(a)
return s},
cf(a){var s,r=$.fI
if(r==null)r=$.fI=Symbol("identityHashCode")
s=a[r]
if(s==null){s=Math.random()*0x3fffffff|0
a[r]=s}return s},
ig(a){var s,r
if(!/^\s*[+-]?(?:Infinity|NaN|(?:\.\d+|\d+(?:\.\d*)?)(?:[eE][+-]?\d+)?)\s*$/.test(a))return null
s=parseFloat(a)
if(isNaN(s)){r=B.d.aL(a)
if(r==="NaN"||r==="+NaN"||r==="-NaN")return s
return null}return s},
cg(a){var s,r,q,p
if(a instanceof A.j)return A.F(A.ao(a),null)
s=J.am(a)
if(s===B.z||s===B.B||t.o.b(a)){r=B.j(a)
if(r!=="Object"&&r!=="")return r
q=a.constructor
if(typeof q=="function"){p=q.name
if(typeof p=="string"&&p!=="Object"&&p!=="")return p}}return A.F(A.ao(a),null)},
fJ(a){var s,r,q
if(a==null||typeof a=="number"||A.eM(a))return J.bB(a)
if(typeof a=="string")return JSON.stringify(a)
if(a instanceof A.Y)return a.j(0)
if(a instanceof A.bn)return a.az(!0)
s=$.hM()
for(r=0;r<1;++r){q=s[r].bJ(a)
if(q!=null)return q}return"Instance of '"+A.cg(a)+"'"},
ic(){return Date.now()},
ie(){var s,r
if($.dP!==0)return
$.dP=1000
if(typeof window=="undefined")return
s=window
if(s==null)return
if(!!s.dartUseDateNowForTicks)return
r=s.performance
if(r==null)return
if(typeof r.now!="function")return
$.dP=1e6
$.dQ=new A.dO(r)},
id(a){var s=a.$thrownJsError
if(s==null)return null
return A.an(s)},
jE(a){return new A.O(!0,a,null,null)},
f(a){return A.z(a,new Error())},
z(a,b){var s
if(a==null)a=new A.U()
b.dartException=a
s=A.k_
if("defineProperty" in Object){Object.defineProperty(b,"message",{get:s})
b.name=""}else b.toString=s
return b},
k_(){return J.bB(this.dartException)},
f0(a,b){throw A.z(a,b==null?new Error():b)},
hx(a,b,c){var s
if(b==null)b=0
if(c==null)c=0
s=Error()
A.f0(A.j2(a,b,c),s)},
j2(a,b,c){var s,r,q,p,o,n,m,l,k
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
return new A.bc("'"+s+"': Cannot "+o+" "+l+k+n)},
M(a){throw A.f(A.Q(a))},
V(a){var s,r,q,p,o,n
a=A.jY(a.replace(String({}),"$receiver$"))
s=a.match(/\\\$[a-zA-Z]+\\\$/g)
if(s==null)s=A.b([],t.s)
r=s.indexOf("\\$arguments\\$")
q=s.indexOf("\\$argumentsExpr\\$")
p=s.indexOf("\\$expr\\$")
o=s.indexOf("\\$method\\$")
n=s.indexOf("\\$receiver\\$")
return new A.e4(a.replace(new RegExp("\\\\\\$arguments\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$argumentsExpr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$expr\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$method\\\\\\$","g"),"((?:x|[^x])*)").replace(new RegExp("\\\\\\$receiver\\\\\\$","g"),"((?:x|[^x])*)"),r,q,p,o,n)},
e5(a){return function($expr$){var $argumentsExpr$="$arguments$"
try{$expr$.$method$($argumentsExpr$)}catch(s){return s.message}}(a)},
fN(a){return function($expr$){try{$expr$.$method$}catch(s){return s.message}}(a)},
f9(a,b){var s=b==null,r=s?null:b.method
return new A.bV(a,r,s?null:b.receiver)},
a9(a){if(a==null)return new A.dM(a)
if(a instanceof A.bK)return A.a7(a,a.a)
if(typeof a!=="object")return a
if("dartException" in a)return A.a7(a,a.dartException)
return A.jC(a)},
a7(a,b){if(t.Q.b(b))if(b.$thrownJsError==null)b.$thrownJsError=a
return b},
jC(a){var s,r,q,p,o,n,m,l,k,j,i,h,g
if(!("message" in a))return a
s=a.message
if("number" in a&&typeof a.number=="number"){r=a.number
q=r&65535
if((B.b.bf(r,16)&8191)===10)switch(q){case 438:return A.a7(a,A.f9(A.o(s)+" (Error "+q+")",null))
case 445:case 5007:A.o(s)
return A.a7(a,new A.b7())}}if(a instanceof TypeError){p=$.hC()
o=$.hD()
n=$.hE()
m=$.hF()
l=$.hI()
k=$.hJ()
j=$.hH()
$.hG()
i=$.hL()
h=$.hK()
g=p.v(s)
if(g!=null)return A.a7(a,A.f9(s,g))
else{g=o.v(s)
if(g!=null){g.method="call"
return A.a7(a,A.f9(s,g))}else if(n.v(s)!=null||m.v(s)!=null||l.v(s)!=null||k.v(s)!=null||j.v(s)!=null||m.v(s)!=null||i.v(s)!=null||h.v(s)!=null)return A.a7(a,new A.b7())}return A.a7(a,new A.ct(typeof s=="string"?s:""))}if(a instanceof RangeError){if(typeof s=="string"&&s.indexOf("call stack")!==-1)return new A.ba()
s=function(b){try{return String(b)}catch(f){}return null}(a)
return A.a7(a,new A.O(!1,null,null,typeof s=="string"?s.replace(/^RangeError:\s*/,""):s))}if(typeof InternalError=="function"&&a instanceof InternalError)if(typeof s=="string"&&s==="too much recursion")return new A.ba()
return a},
an(a){var s
if(a instanceof A.bK)return a.b
if(a==null)return new A.bq(a)
s=a.$cachedTrace
if(s!=null)return s
s=new A.bq(a)
if(typeof a==="object")a.$cachedTrace=s
return s},
f_(a){if(a==null)return J.N(a)
if(typeof a=="object")return A.cf(a)
return J.N(a)},
jM(a,b){var s,r,q,p=a.length
for(s=0;s<p;s=q){r=s+1
q=r+1
b.t(0,a[s],a[r])}return b},
jb(a,b,c,d,e,f){switch(b){case 0:return a.$0()
case 1:return a.$1(c)
case 2:return a.$2(c,d)
case 3:return a.$3(c,d,e)
case 4:return a.$4(c,d,e,f)}throw A.f(A.fC("Unsupported number of arguments for wrapped closure"))},
cF(a,b){var s=a.$identity
if(!!s)return s
s=A.jI(a,b)
a.$identity=s
return s},
jI(a,b){var s
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
return function(c,d,e){return function(f,g,h,i){return e(c,d,f,g,h,i)}}(a,b,A.jb)},
hY(a2){var s,r,q,p,o,n,m,l,k,j,i=a2.co,h=a2.iS,g=a2.iI,f=a2.nDA,e=a2.aI,d=a2.fs,c=a2.cs,b=d[0],a=c[0],a0=i[b],a1=a2.fT
a1.toString
s=h?Object.create(new A.cp().constructor.prototype):Object.create(new A.at(null,null).constructor.prototype)
s.$initialize=s.constructor
r=h?function static_tear_off(){this.$initialize()}:function tear_off(a3,a4){this.$initialize(a3,a4)}
s.constructor=r
r.prototype=s
s.$_name=b
s.$_target=a0
q=!h
if(q)p=A.fB(b,a0,g,f)
else{s.$static_name=b
p=a0}s.$S=A.hU(a1,h,g)
s[a]=p
for(o=p,n=1;n<d.length;++n){m=d[n]
if(typeof m=="string"){l=i[m]
k=m
m=l}else k=""
j=c[n]
if(j!=null){if(q)m=A.fB(k,m,g,f)
s[j]=m}if(n===e)o=m}s.$C=o
s.$R=a2.rC
s.$D=a2.dV
return r},
hU(a,b,c){if(typeof a=="number")return a
if(typeof a=="string"){if(b)throw A.f("Cannot compute signature for static tearoff.")
return function(d,e){return function(){return e(this,d)}}(a,A.hR)}throw A.f("Error in functionType of tearoff")},
hV(a,b,c,d){var s=A.fA
switch(b?-1:a){case 0:return function(e,f){return function(){return f(this)[e]()}}(c,s)
case 1:return function(e,f){return function(g){return f(this)[e](g)}}(c,s)
case 2:return function(e,f){return function(g,h){return f(this)[e](g,h)}}(c,s)
case 3:return function(e,f){return function(g,h,i){return f(this)[e](g,h,i)}}(c,s)
case 4:return function(e,f){return function(g,h,i,j){return f(this)[e](g,h,i,j)}}(c,s)
case 5:return function(e,f){return function(g,h,i,j,k){return f(this)[e](g,h,i,j,k)}}(c,s)
default:return function(e,f){return function(){return e.apply(f(this),arguments)}}(d,s)}},
fB(a,b,c,d){if(c)return A.hX(a,b,d)
return A.hV(b.length,d,a,b)},
hW(a,b,c,d){var s=A.fA,r=A.hS
switch(b?-1:a){case 0:throw A.f(new A.cj("Intercepted function with no arguments."))
case 1:return function(e,f,g){return function(){return f(this)[e](g(this))}}(c,r,s)
case 2:return function(e,f,g){return function(h){return f(this)[e](g(this),h)}}(c,r,s)
case 3:return function(e,f,g){return function(h,i){return f(this)[e](g(this),h,i)}}(c,r,s)
case 4:return function(e,f,g){return function(h,i,j){return f(this)[e](g(this),h,i,j)}}(c,r,s)
case 5:return function(e,f,g){return function(h,i,j,k){return f(this)[e](g(this),h,i,j,k)}}(c,r,s)
case 6:return function(e,f,g){return function(h,i,j,k,l){return f(this)[e](g(this),h,i,j,k,l)}}(c,r,s)
default:return function(e,f,g){return function(){var q=[g(this)]
Array.prototype.push.apply(q,arguments)
return e.apply(f(this),q)}}(d,r,s)}},
hX(a,b,c){var s,r
if($.fy==null)$.fy=A.fx("interceptor")
if($.fz==null)$.fz=A.fx("receiver")
s=b.length
r=A.hW(s,c,a,b)
return r},
fn(a){return A.hY(a)},
hR(a,b){return A.bw(v.typeUniverse,A.ao(a.a),b)},
fA(a){return a.a},
hS(a){return a.b},
fx(a){var s,r,q,p=new A.at("receiver","interceptor"),o=Object.getOwnPropertyNames(p)
o.$flags=1
s=o
for(o=s.length,r=0;r<o;++r){q=s[r]
if(p[q]===a)return q}throw A.f(A.aQ("Field name "+a+" not found.",null))},
eS(a){return v.getIsolateTag(a)},
jT(a){var s,r,q,p,o,n=$.hs.$1(a),m=$.eQ[n]
if(m!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}s=$.eW[n]
if(s!=null)return s
r=v.interceptorsByTag[n]
if(r==null){q=$.hl.$2(a,n)
if(q!=null){m=$.eQ[q]
if(m!=null){Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}s=$.eW[q]
if(s!=null)return s
r=v.interceptorsByTag[q]
n=q}}if(r==null)return null
s=r.prototype
p=n[0]
if(p==="!"){m=A.eZ(s)
$.eQ[n]=m
Object.defineProperty(a,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
return m.i}if(p==="~"){$.eW[n]=s
return s}if(p==="-"){o=A.eZ(s)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:o,enumerable:false,writable:true,configurable:true})
return o.i}if(p==="+")return A.hu(a,s)
if(p==="*")throw A.f(A.fO(n))
if(v.leafTags[n]===true){o=A.eZ(s)
Object.defineProperty(Object.getPrototypeOf(a),v.dispatchPropertyName,{value:o,enumerable:false,writable:true,configurable:true})
return o.i}else return A.hu(a,s)},
hu(a,b){var s=Object.getPrototypeOf(a)
Object.defineProperty(s,v.dispatchPropertyName,{value:J.fs(b,s,null,null),enumerable:false,writable:true,configurable:true})
return b},
eZ(a){return J.fs(a,!1,null,!!a.$iE)},
jV(a,b,c){var s=b.prototype
if(v.leafTags[a]===true)return A.eZ(s)
else return J.fs(s,c,null,null)},
jP(){if(!0===$.fq)return
$.fq=!0
A.jQ()},
jQ(){var s,r,q,p,o,n,m,l
$.eQ=Object.create(null)
$.eW=Object.create(null)
A.jO()
s=v.interceptorsByTag
r=Object.getOwnPropertyNames(s)
if(typeof window!="undefined"){window
q=function(){}
for(p=0;p<r.length;++p){o=r[p]
n=$.hw.$1(o)
if(n!=null){m=A.jV(o,s[o],n)
if(m!=null){Object.defineProperty(n,v.dispatchPropertyName,{value:m,enumerable:false,writable:true,configurable:true})
q.prototype=n}}}}for(p=0;p<r.length;++p){o=r[p]
if(/^[A-Za-z_]/.test(o)){l=s[o]
s["!"+o]=l
s["~"+o]=l
s["-"+o]=l
s["+"+o]=l
s["*"+o]=l}}},
jO(){var s,r,q,p,o,n,m=B.o()
m=A.aO(B.p,A.aO(B.q,A.aO(B.k,A.aO(B.k,A.aO(B.r,A.aO(B.t,A.aO(B.u(B.j),m)))))))
if(typeof dartNativeDispatchHooksTransformer!="undefined"){s=dartNativeDispatchHooksTransformer
if(typeof s=="function")s=[s]
if(Array.isArray(s))for(r=0;r<s.length;++r){q=s[r]
if(typeof q=="function")m=q(m)||m}}p=m.getTag
o=m.getUnknownTag
n=m.prototypeForTag
$.hs=new A.eT(p)
$.hl=new A.eU(o)
$.hw=new A.eV(n)},
aO(a,b){return a(b)||b},
jJ(a,b){var s=b.length,r=v.rttc[""+s+";"+a]
if(r==null)return null
if(s===0)return r
if(s===r.length)return r.apply(null,b)
return r(b)},
i6(a,b,c,d,e,f){var s=b?"m":"",r=c?"":"i",q=d?"u":"",p=e?"s":"",o=function(g,h){try{return new RegExp(g,h)}catch(n){return n}}(a,s+r+q+p+f)
if(o instanceof RegExp)return o
throw A.f(A.fD("Illegal RegExp pattern ("+String(o)+")",a))},
jY(a){if(/[[\]{}()*+?.\\^$|]/.test(a))return a.replace(/[[\]{}()*+?.\\^$|]/g,"\\$&")
return a},
a3:function a3(a,b,c){this.a=a
this.b=b
this.c=c},
dO:function dO(a){this.a=a},
b8:function b8(){},
e4:function e4(a,b,c,d,e,f){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f},
b7:function b7(){},
bV:function bV(a,b,c){this.a=a
this.b=b
this.c=c},
ct:function ct(a){this.a=a},
dM:function dM(a){this.a=a},
bK:function bK(){},
bq:function bq(a){this.a=a
this.b=null},
Y:function Y(){},
bG:function bG(){},
bH:function bH(){},
cr:function cr(){},
cp:function cp(){},
at:function at(a,b){this.a=a
this.b=b},
cj:function cj(a){this.a=a},
ad:function ad(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
dH:function dH(a,b){var _=this
_.a=a
_.b=b
_.d=_.c=null},
af:function af(a,b){this.a=a
this.$ti=b},
bX:function bX(a,b,c){var _=this
_.a=a
_.b=b
_.c=c
_.d=null},
bY:function bY(a,b,c){var _=this
_.a=a
_.b=b
_.c=c
_.d=null},
ae:function ae(a,b){this.a=a
this.$ti=b},
bW:function bW(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=null
_.$ti=d},
eT:function eT(a){this.a=a},
eU:function eU(a){this.a=a},
eV:function eV(a){this.a=a},
bn:function bn(){},
cA:function cA(){},
dF:function dF(a,b){var _=this
_.a=a
_.b=b
_.e=_.d=_.c=null},
aD:function aD(){},
b5:function b5(){},
c1:function c1(){},
aE:function aE(){},
b3:function b3(){},
b4:function b4(){},
c2:function c2(){},
c3:function c3(){},
c4:function c4(){},
c5:function c5(){},
c6:function c6(){},
c7:function c7(){},
c8:function c8(){},
b6:function b6(){},
c9:function c9(){},
bj:function bj(){},
bk:function bk(){},
bl:function bl(){},
bm:function bm(){},
fa(a,b){var s=b.c
return s==null?b.c=A.bu(a,"aW",[b.x]):s},
fK(a){var s=a.w
if(s===6||s===7)return A.fK(a.x)
return s===11||s===12},
ij(a){return a.as},
eR(a){return A.ey(v.typeUniverse,a,!1)},
aj(a1,a2,a3,a4){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0=a2.w
switch(a0){case 5:case 1:case 2:case 3:case 4:return a2
case 6:s=a2.x
r=A.aj(a1,s,a3,a4)
if(r===s)return a2
return A.fY(a1,r,!0)
case 7:s=a2.x
r=A.aj(a1,s,a3,a4)
if(r===s)return a2
return A.fX(a1,r,!0)
case 8:q=a2.y
p=A.aN(a1,q,a3,a4)
if(p===q)return a2
return A.bu(a1,a2.x,p)
case 9:o=a2.x
n=A.aj(a1,o,a3,a4)
m=a2.y
l=A.aN(a1,m,a3,a4)
if(n===o&&l===m)return a2
return A.fg(a1,n,l)
case 10:k=a2.x
j=a2.y
i=A.aN(a1,j,a3,a4)
if(i===j)return a2
return A.fZ(a1,k,i)
case 11:h=a2.x
g=A.aj(a1,h,a3,a4)
f=a2.y
e=A.jz(a1,f,a3,a4)
if(g===h&&e===f)return a2
return A.fW(a1,g,e)
case 12:d=a2.y
a4+=d.length
c=A.aN(a1,d,a3,a4)
o=a2.x
n=A.aj(a1,o,a3,a4)
if(c===d&&n===o)return a2
return A.fh(a1,n,c,!0)
case 13:b=a2.x
if(b<a4)return a2
a=a3[b-a4]
if(a==null)return a2
return a
default:throw A.f(A.bF("Attempted to substitute unexpected RTI kind "+a0))}},
aN(a,b,c,d){var s,r,q,p,o=b.length,n=A.ez(o)
for(s=!1,r=0;r<o;++r){q=b[r]
p=A.aj(a,q,c,d)
if(p!==q)s=!0
n[r]=p}return s?n:b},
jA(a,b,c,d){var s,r,q,p,o,n,m=b.length,l=A.ez(m)
for(s=!1,r=0;r<m;r+=3){q=b[r]
p=b[r+1]
o=b[r+2]
n=A.aj(a,o,c,d)
if(n!==o)s=!0
l.splice(r,3,q,p,n)}return s?l:b},
jz(a,b,c,d){var s,r=b.a,q=A.aN(a,r,c,d),p=b.b,o=A.aN(a,p,c,d),n=b.c,m=A.jA(a,n,c,d)
if(q===r&&o===p&&m===n)return b
s=new A.cx()
s.a=q
s.b=o
s.c=m
return s},
b(a,b){a[v.arrayRti]=b
return a},
ho(a){var s=a.$S
if(s!=null){if(typeof s=="number")return A.jN(s)
return a.$S()}return null},
jR(a,b){var s
if(A.fK(b))if(a instanceof A.Y){s=A.ho(a)
if(s!=null)return s}return A.ao(a)},
ao(a){if(a instanceof A.j)return A.a5(a)
if(Array.isArray(a))return A.cC(a)
return A.fk(J.am(a))},
cC(a){var s=a[v.arrayRti],r=t.b
if(s==null)return r
if(s.constructor!==r.constructor)return r
return s},
a5(a){var s=a.$ti
return s!=null?s:A.fk(a)},
fk(a){var s=a.constructor,r=s.$ccache
if(r!=null)return r
return A.j9(a,s)},
j9(a,b){var s=a instanceof A.Y?Object.getPrototypeOf(Object.getPrototypeOf(a)).constructor:b,r=A.iM(v.typeUniverse,s.name)
b.$ccache=r
return r},
jN(a){var s,r=v.types,q=r[a]
if(typeof q=="string"){s=A.ey(v.typeUniverse,q,!1)
r[a]=s
return s}return q},
hr(a){return A.al(A.a5(a))},
fm(a){var s
if(a instanceof A.bn)return A.jL(a.$r,a.ao())
s=a instanceof A.Y?A.ho(a):null
if(s!=null)return s
if(t.R.b(a))return J.hP(a).a
if(Array.isArray(a))return A.cC(a)
return A.ao(a)},
al(a){var s=a.r
return s==null?a.r=new A.ex(a):s},
jL(a,b){var s,r,q=b,p=q.length
if(p===0)return t.F
s=A.bw(v.typeUniverse,A.fm(q[0]),"@<0>")
for(r=1;r<p;++r)s=A.h0(v.typeUniverse,s,A.fm(q[r]))
return A.bw(v.typeUniverse,s,a)},
L(a){return A.al(A.ey(v.typeUniverse,a,!1))},
j8(a){var s=this
s.b=A.jx(s)
return s.b(a)},
jx(a){var s,r,q,p
if(a===t.K)return A.ji
if(A.ap(a))return A.jm
s=a.w
if(s===6)return A.j6
if(s===1)return A.hc
if(s===7)return A.jc
r=A.jw(a)
if(r!=null)return r
if(s===8){q=a.x
if(a.y.every(A.ap)){a.f="$i"+q
if(q==="k")return A.jg
if(a===t.m)return A.jf
return A.jl}}else if(s===10){p=A.jJ(a.x,a.y)
return p==null?A.hc:p}return A.j4},
jw(a){if(a.w===8){if(a===t.S)return A.jd
if(a===t.i||a===t.H)return A.jh
if(a===t.N)return A.jk
if(a===t.y)return A.eM}return null},
j7(a){var s=this,r=A.j3
if(A.ap(s))r=A.iY
else if(s===t.K)r=A.iW
else if(A.aP(s)){r=A.j5
if(s===t.a3)r=A.iS
else if(s===t.u)r=A.iX
else if(s===t.cG)r=A.iO
else if(s===t.be)r=A.iV
else if(s===t.I)r=A.iQ
else if(s===t.aQ)r=A.iT}else if(s===t.S)r=A.iR
else if(s===t.N)r=A.h5
else if(s===t.y)r=A.h4
else if(s===t.H)r=A.iU
else if(s===t.i)r=A.iP
else if(s===t.m)r=A.aL
s.a=r
return s.a(a)},
j4(a){var s=this
if(a==null)return A.aP(s)
return A.jS(v.typeUniverse,A.jR(a,s),s)},
j6(a){if(a==null)return!0
return this.x.b(a)},
jl(a){var s,r=this
if(a==null)return A.aP(r)
s=r.f
if(a instanceof A.j)return!!a[s]
return!!J.am(a)[s]},
jg(a){var s,r=this
if(a==null)return A.aP(r)
if(typeof a!="object")return!1
if(Array.isArray(a))return!0
s=r.f
if(a instanceof A.j)return!!a[s]
return!!J.am(a)[s]},
jf(a){var s=this
if(a==null)return!1
if(typeof a=="object"){if(a instanceof A.j)return!!a[s.f]
return!0}if(typeof a=="function")return!0
return!1},
hb(a){if(typeof a=="object"){if(a instanceof A.j)return t.m.b(a)
return!0}if(typeof a=="function")return!0
return!1},
j3(a){var s=this
if(a==null){if(A.aP(s))return a}else if(s.b(a))return a
throw A.z(A.h8(a,s),new Error())},
j5(a){var s=this
if(a==null||s.b(a))return a
throw A.z(A.h8(a,s),new Error())},
h8(a,b){return new A.bs("TypeError: "+A.fP(a,A.F(b,null)))},
fP(a,b){return A.d1(a)+": type '"+A.F(A.fm(a),null)+"' is not a subtype of type '"+b+"'"},
H(a,b){return new A.bs("TypeError: "+A.fP(a,b))},
jc(a){var s=this
return s.x.b(a)||A.fa(v.typeUniverse,s).b(a)},
ji(a){return a!=null},
iW(a){if(a!=null)return a
throw A.z(A.H(a,"Object"),new Error())},
jm(a){return!0},
iY(a){return a},
hc(a){return!1},
eM(a){return!0===a||!1===a},
h4(a){if(!0===a)return!0
if(!1===a)return!1
throw A.z(A.H(a,"bool"),new Error())},
iO(a){if(!0===a)return!0
if(!1===a)return!1
if(a==null)return a
throw A.z(A.H(a,"bool?"),new Error())},
iP(a){if(typeof a=="number")return a
throw A.z(A.H(a,"double"),new Error())},
iQ(a){if(typeof a=="number")return a
if(a==null)return a
throw A.z(A.H(a,"double?"),new Error())},
jd(a){return typeof a=="number"&&Math.floor(a)===a},
iR(a){if(typeof a=="number"&&Math.floor(a)===a)return a
throw A.z(A.H(a,"int"),new Error())},
iS(a){if(typeof a=="number"&&Math.floor(a)===a)return a
if(a==null)return a
throw A.z(A.H(a,"int?"),new Error())},
jh(a){return typeof a=="number"},
iU(a){if(typeof a=="number")return a
throw A.z(A.H(a,"num"),new Error())},
iV(a){if(typeof a=="number")return a
if(a==null)return a
throw A.z(A.H(a,"num?"),new Error())},
jk(a){return typeof a=="string"},
h5(a){if(typeof a=="string")return a
throw A.z(A.H(a,"String"),new Error())},
iX(a){if(typeof a=="string")return a
if(a==null)return a
throw A.z(A.H(a,"String?"),new Error())},
aL(a){if(A.hb(a))return a
throw A.z(A.H(a,"JSObject"),new Error())},
iT(a){if(a==null)return a
if(A.hb(a))return a
throw A.z(A.H(a,"JSObject?"),new Error())},
hj(a,b){var s,r,q
for(s="",r="",q=0;q<a.length;++q,r=", ")s+=r+A.F(a[q],b)
return s},
js(a,b){var s,r,q,p,o,n,m=a.x,l=a.y
if(""===m)return"("+A.hj(l,b)+")"
s=l.length
r=m.split(",")
q=r.length-s
for(p="(",o="",n=0;n<s;++n,o=", "){p+=o
if(q===0)p+="{"
p+=A.F(l[n],b)
if(q>=0)p+=" "+r[q];++q}return p+"})"},
h9(a1,a2,a3){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a=", ",a0=null
if(a3!=null){s=a3.length
if(a2==null)a2=A.b([],t.s)
else a0=a2.length
r=a2.length
for(q=s;q>0;--q)a2.push("T"+(r+q))
for(p=t.X,o="<",n="",q=0;q<s;++q,n=a){o=o+n+a2[a2.length-1-q]
m=a3[q]
l=m.w
if(!(l===2||l===3||l===4||l===5||m===p))o+=" extends "+A.F(m,a2)}o+=">"}else o=""
p=a1.x
k=a1.y
j=k.a
i=j.length
h=k.b
g=h.length
f=k.c
e=f.length
d=A.F(p,a2)
for(c="",b="",q=0;q<i;++q,b=a)c+=b+A.F(j[q],a2)
if(g>0){c+=b+"["
for(b="",q=0;q<g;++q,b=a)c+=b+A.F(h[q],a2)
c+="]"}if(e>0){c+=b+"{"
for(b="",q=0;q<e;q+=3,b=a){c+=b
if(f[q+1])c+="required "
c+=A.F(f[q+2],a2)+" "+f[q]}c+="}"}if(a0!=null){a2.toString
a2.length=a0}return o+"("+c+") => "+d},
F(a,b){var s,r,q,p,o,n,m=a.w
if(m===5)return"erased"
if(m===2)return"dynamic"
if(m===3)return"void"
if(m===1)return"Never"
if(m===4)return"any"
if(m===6){s=a.x
r=A.F(s,b)
q=s.w
return(q===11||q===12?"("+r+")":r)+"?"}if(m===7)return"FutureOr<"+A.F(a.x,b)+">"
if(m===8){p=A.jB(a.x)
o=a.y
return o.length>0?p+("<"+A.hj(o,b)+">"):p}if(m===10)return A.js(a,b)
if(m===11)return A.h9(a,b,null)
if(m===12)return A.h9(a.x,b,a.y)
if(m===13){n=a.x
return b[b.length-1-n]}return"?"},
jB(a){var s=A.hy(a)
if(s!=null)return s
return"minified:"+a},
iN(a,b){var s=a.tR[b]
while(typeof s=="string")s=a.tR[s]
return s},
iM(a,b){var s,r,q,p,o,n=a.eT,m=n[b]
if(m==null)return A.ey(a,b,!1)
else if(typeof m=="number"){s=m
r=A.bv(a,5,"#")
q=A.ez(s)
for(p=0;p<s;++p)q[p]=r
o=A.bu(a,b,q)
n[b]=o
return o}else return m},
iL(a,b){return A.h1(a.tR,b)},
iK(a,b){return A.h1(a.eT,b)},
ey(a,b,c){var s,r=a.eC,q=r.get(b)
if(q!=null)return q
s=A.h_(a,null,b,!1)
r.set(b,s)
return s},
bw(a,b,c){var s,r,q=b.z
if(q==null)q=b.z=new Map()
s=q.get(c)
if(s!=null)return s
r=A.h_(a,b,c,!0)
q.set(c,r)
return r},
h0(a,b,c){var s,r,q,p=b.Q
if(p==null)p=b.Q=new Map()
s=c.as
r=p.get(s)
if(r!=null)return r
q=A.fg(a,b,c.w===9?c.y:[c])
p.set(s,q)
return q},
h_(a,b,c,d){return A.iB(A.iv(a,b,c,d))},
a4(a,b){b.a=A.j7
b.b=A.j8
return b},
bv(a,b,c){var s,r,q=a.eC.get(c)
if(q!=null)return q
s=new A.J(null,null)
s.w=b
s.as=c
r=A.a4(a,s)
a.eC.set(c,r)
return r},
fY(a,b,c){var s,r=b.as+"?",q=a.eC.get(r)
if(q!=null)return q
s=A.iI(a,b,r,c)
a.eC.set(r,s)
return s},
iI(a,b,c,d){var s,r,q
if(d){s=b.w
r=!0
if(!A.ap(b))if(!(b===t.P||b===t.T))if(s!==6)r=s===7&&A.aP(b.x)
if(r)return b
else if(s===1)return t.P}q=new A.J(null,null)
q.w=6
q.x=b
q.as=c
return A.a4(a,q)},
fX(a,b,c){var s,r=b.as+"/",q=a.eC.get(r)
if(q!=null)return q
s=A.iG(a,b,r,c)
a.eC.set(r,s)
return s},
iG(a,b,c,d){var s,r
if(d){s=b.w
if(A.ap(b)||b===t.K)return b
else if(s===1)return A.bu(a,"aW",[b])
else if(b===t.P||b===t.T)return t.bc}r=new A.J(null,null)
r.w=7
r.x=b
r.as=c
return A.a4(a,r)},
iJ(a,b){var s,r,q=""+b+"^",p=a.eC.get(q)
if(p!=null)return p
s=new A.J(null,null)
s.w=13
s.x=b
s.as=q
r=A.a4(a,s)
a.eC.set(q,r)
return r},
bt(a){var s,r,q,p=a.length
for(s="",r="",q=0;q<p;++q,r=",")s+=r+a[q].as
return s},
iF(a){var s,r,q,p,o,n=a.length
for(s="",r="",q=0;q<n;q+=3,r=","){p=a[q]
o=a[q+1]?"!":":"
s+=r+p+o+a[q+2].as}return s},
bu(a,b,c){var s,r,q,p=b
if(c.length>0)p+="<"+A.bt(c)+">"
s=a.eC.get(p)
if(s!=null)return s
r=new A.J(null,null)
r.w=8
r.x=b
r.y=c
if(c.length>0)r.c=c[0]
r.as=p
q=A.a4(a,r)
a.eC.set(p,q)
return q},
fg(a,b,c){var s,r,q,p,o,n
if(b.w===9){s=b.x
r=b.y.concat(c)}else{r=c
s=b}q=s.as+(";<"+A.bt(r)+">")
p=a.eC.get(q)
if(p!=null)return p
o=new A.J(null,null)
o.w=9
o.x=s
o.y=r
o.as=q
n=A.a4(a,o)
a.eC.set(q,n)
return n},
fZ(a,b,c){var s,r,q="+"+(b+"("+A.bt(c)+")"),p=a.eC.get(q)
if(p!=null)return p
s=new A.J(null,null)
s.w=10
s.x=b
s.y=c
s.as=q
r=A.a4(a,s)
a.eC.set(q,r)
return r},
fW(a,b,c){var s,r,q,p,o,n=b.as,m=c.a,l=m.length,k=c.b,j=k.length,i=c.c,h=i.length,g="("+A.bt(m)
if(j>0){s=l>0?",":""
g+=s+"["+A.bt(k)+"]"}if(h>0){s=l>0?",":""
g+=s+"{"+A.iF(i)+"}"}r=n+(g+")")
q=a.eC.get(r)
if(q!=null)return q
p=new A.J(null,null)
p.w=11
p.x=b
p.y=c
p.as=r
o=A.a4(a,p)
a.eC.set(r,o)
return o},
fh(a,b,c,d){var s,r=b.as+("<"+A.bt(c)+">"),q=a.eC.get(r)
if(q!=null)return q
s=A.iH(a,b,c,r,d)
a.eC.set(r,s)
return s},
iH(a,b,c,d,e){var s,r,q,p,o,n,m,l
if(e){s=c.length
r=A.ez(s)
for(q=0,p=0;p<s;++p){o=c[p]
if(o.w===1){r[p]=o;++q}}if(q>0){n=A.aj(a,b,r,0)
m=A.aN(a,c,r,0)
return A.fh(a,n,m,c!==m)}}l=new A.J(null,null)
l.w=12
l.x=b
l.y=c
l.as=d
return A.a4(a,l)},
iv(a,b,c,d){return{u:a,e:b,r:c,s:[],p:0,n:d}},
iB(a){var s,r,q,p,o,n,m,l=a.r,k=a.s
for(s=l.length,r=0;r<s;){q=l.charCodeAt(r)
if(q>=48&&q<=57)r=A.ix(r+1,q,l,k)
else if((((q|32)>>>0)-97&65535)<26||q===95||q===36||q===124)r=A.fU(a,r,l,k,!1)
else if(q===46)r=A.fU(a,r,l,k,!0)
else{++r
switch(q){case 44:break
case 58:k.push(!1)
break
case 33:k.push(!0)
break
case 59:k.push(A.ai(a.u,a.e,k.pop()))
break
case 94:k.push(A.iJ(a.u,k.pop()))
break
case 35:k.push(A.bv(a.u,5,"#"))
break
case 64:k.push(A.bv(a.u,2,"@"))
break
case 126:k.push(A.bv(a.u,3,"~"))
break
case 60:k.push(a.p)
a.p=k.length
break
case 62:A.iz(a,k)
break
case 38:A.iy(a,k)
break
case 63:p=a.u
k.push(A.fY(p,A.ai(p,a.e,k.pop()),a.n))
break
case 47:p=a.u
k.push(A.fX(p,A.ai(p,a.e,k.pop()),a.n))
break
case 40:k.push(-3)
k.push(a.p)
a.p=k.length
break
case 41:A.iw(a,k)
break
case 91:k.push(a.p)
a.p=k.length
break
case 93:o=k.splice(a.p)
A.fV(a.u,a.e,o)
a.p=k.pop()
k.push(o)
k.push(-1)
break
case 123:k.push(a.p)
a.p=k.length
break
case 125:o=k.splice(a.p)
A.iC(a.u,a.e,o)
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
return A.ai(a.u,a.e,m)},
ix(a,b,c,d){var s,r,q=b-48
for(s=c.length;a<s;++a){r=c.charCodeAt(a)
if(!(r>=48&&r<=57))break
q=q*10+(r-48)}d.push(q)
return a},
fU(a,b,c,d,e){var s,r,q,p,o,n,m=b+1
for(s=c.length;m<s;++m){r=c.charCodeAt(m)
if(r===46){if(e)break
e=!0}else{if(!((((r|32)>>>0)-97&65535)<26||r===95||r===36||r===124))q=r>=48&&r<=57
else q=!0
if(!q)break}}p=c.substring(b,m)
if(e){s=a.u
o=a.e
if(o.w===9)o=o.x
n=A.iN(s,o.x)[p]
if(n==null)A.f0('No "'+p+'" in "'+A.ij(o)+'"')
d.push(A.bw(s,o,n))}else d.push(p)
return m},
iz(a,b){var s,r=a.u,q=A.fT(a,b),p=b.pop()
if(typeof p=="string")b.push(A.bu(r,p,q))
else{s=A.ai(r,a.e,p)
switch(s.w){case 11:b.push(A.fh(r,s,q,a.n))
break
default:b.push(A.fg(r,s,q))
break}}},
iw(a,b){var s,r,q,p=a.u,o=b.pop(),n=null,m=null
if(typeof o=="number")switch(o){case-1:n=b.pop()
break
case-2:m=b.pop()
break
default:b.push(o)
break}else b.push(o)
s=A.fT(a,b)
o=b.pop()
switch(o){case-3:o=b.pop()
if(n==null)n=p.sEA
if(m==null)m=p.sEA
r=A.ai(p,a.e,o)
q=new A.cx()
q.a=s
q.b=n
q.c=m
b.push(A.fW(p,r,q))
return
case-4:b.push(A.fZ(p,b.pop(),s))
return
default:throw A.f(A.bF("Unexpected state under `()`: "+A.o(o)))}},
iy(a,b){var s=b.pop()
if(0===s){b.push(A.bv(a.u,1,"0&"))
return}if(1===s){b.push(A.bv(a.u,4,"1&"))
return}throw A.f(A.bF("Unexpected extended operation "+A.o(s)))},
fT(a,b){var s=b.splice(a.p)
A.fV(a.u,a.e,s)
a.p=b.pop()
return s},
ai(a,b,c){if(typeof c=="string")return A.bu(a,c,a.sEA)
else if(typeof c=="number"){b.toString
return A.iA(a,b,c)}else return c},
fV(a,b,c){var s,r=c.length
for(s=0;s<r;++s)c[s]=A.ai(a,b,c[s])},
iC(a,b,c){var s,r=c.length
for(s=2;s<r;s+=3)c[s]=A.ai(a,b,c[s])},
iA(a,b,c){var s,r,q=b.w
if(q===9){if(c===0)return b.x
s=b.y
r=s.length
if(c<=r)return s[c-1]
c-=r
b=b.x
q=b.w}else if(c===0)return b
if(q!==8)throw A.f(A.bF("Indexed base must be an interface type"))
s=b.y
if(c<=s.length)return s[c-1]
throw A.f(A.bF("Bad index "+c+" for "+b.j(0)))},
jS(a,b,c){var s,r=b.d
if(r==null)r=b.d=new Map()
s=r.get(c)
if(s==null){s=A.y(a,b,null,c,null)
r.set(c,s)}return s},
y(a,b,c,d,e){var s,r,q,p,o,n,m,l,k,j,i
if(b===d)return!0
if(A.ap(d))return!0
s=b.w
if(s===4)return!0
if(A.ap(b))return!1
if(b.w===1)return!0
r=s===13
if(r)if(A.y(a,c[b.x],c,d,e))return!0
q=d.w
p=t.P
if(b===p||b===t.T){if(q===7)return A.y(a,b,c,d.x,e)
return d===p||d===t.T||q===6}if(d===t.K){if(s===7)return A.y(a,b.x,c,d,e)
return s!==6}if(s===7){if(!A.y(a,b.x,c,d,e))return!1
return A.y(a,A.fa(a,b),c,d,e)}if(s===6)return A.y(a,p,c,d,e)&&A.y(a,b.x,c,d,e)
if(q===7){if(A.y(a,b,c,d.x,e))return!0
return A.y(a,b,c,A.fa(a,d),e)}if(q===6)return A.y(a,b,c,p,e)||A.y(a,b,c,d.x,e)
if(r)return!1
p=s!==11
if((!p||s===12)&&d===t.Z)return!0
o=s===10
if(o&&d===t.G)return!0
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
if(!A.y(a,j,c,i,e)||!A.y(a,i,e,j,c))return!1}return A.ha(a,b.x,c,d.x,e)}if(q===11){if(b===t.g)return!0
if(p)return!1
return A.ha(a,b,c,d,e)}if(s===8){if(q!==8)return!1
return A.je(a,b,c,d,e)}if(o&&q===10)return A.jj(a,b,c,d,e)
return!1},
ha(a3,a4,a5,a6,a7){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2
if(!A.y(a3,a4.x,a5,a6.x,a7))return!1
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
if(!A.y(a3,p[h],a7,g,a5))return!1}for(h=0;h<m;++h){g=l[h]
if(!A.y(a3,p[o+h],a7,g,a5))return!1}for(h=0;h<i;++h){g=l[m+h]
if(!A.y(a3,k[h],a7,g,a5))return!1}f=s.c
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
if(!A.y(a3,e[a+2],a7,g,a5))return!1
break}}while(b<d){if(f[b+1])return!1
b+=3}return!0},
je(a,b,c,d,e){var s,r,q,p,o,n=b.x,m=d.x
while(n!==m){s=a.tR[n]
if(s==null)return!1
if(typeof s=="string"){n=s
continue}r=s[m]
if(r==null)return!1
q=r.length
p=q>0?new Array(q):v.typeUniverse.sEA
for(o=0;o<q;++o)p[o]=A.bw(a,b,r[o])
return A.h3(a,p,null,c,d.y,e)}return A.h3(a,b.y,null,c,d.y,e)},
h3(a,b,c,d,e,f){var s,r=b.length
for(s=0;s<r;++s)if(!A.y(a,b[s],d,e[s],f))return!1
return!0},
jj(a,b,c,d,e){var s,r=b.y,q=d.y,p=r.length
if(p!==q.length)return!1
if(b.x!==d.x)return!1
for(s=0;s<p;++s)if(!A.y(a,r[s],c,q[s],e))return!1
return!0},
aP(a){var s=a.w,r=!0
if(!(a===t.P||a===t.T))if(!A.ap(a))if(s!==6)r=s===7&&A.aP(a.x)
return r},
ap(a){var s=a.w
return s===2||s===3||s===4||s===5||a===t.X},
h1(a,b){var s,r,q=Object.keys(b),p=q.length
for(s=0;s<p;++s){r=q[s]
a[r]=b[r]}},
ez(a){return a>0?new Array(a):v.typeUniverse.sEA},
J:function J(a,b){var _=this
_.a=a
_.b=b
_.r=_.f=_.d=_.c=null
_.w=0
_.as=_.Q=_.z=_.y=_.x=null},
cx:function cx(){this.c=this.b=this.a=null},
ex:function ex(a){this.a=a},
cw:function cw(){},
bs:function bs(a){this.a=a},
iq(){var s,r,q
if(self.scheduleImmediate!=null)return A.jF()
if(self.MutationObserver!=null&&self.document!=null){s={}
r=self.document.createElement("div")
q=self.document.createElement("span")
s.a=null
new self.MutationObserver(A.cF(new A.eb(s),1)).observe(r,{childList:true})
return new A.ea(s,r,q)}else if(self.setImmediate!=null)return A.jG()
return A.jH()},
ir(a){self.scheduleImmediate(A.cF(new A.ec(a),0))},
is(a){self.setImmediate(A.cF(new A.ed(a),0))},
it(a){A.fd(B.x,a)},
fd(a,b){return A.iD(a.a/1000|0,b)},
fM(a,b){return A.iE(a.a/1000|0,b)},
iD(a,b){var s=new A.br()
s.aX(a,b)
return s},
iE(a,b){var s=new A.br()
s.aY(a,b)
return s},
f2(a){var s
if(t.Q.b(a)){s=a.gN()
if(s!=null)return s}return B.w},
fE(a,b,c){var s=new A.K($.w,c.i("K<0>"))
A.io(a,new A.d6(b,s,c))
return s},
ja(a,b){if($.w===B.c)return null
return null},
fe(a,b,c){var s,r,q,p={},o=p.a=a
while(s=o.a,(s&4)!==0){o=o.c
p.a=o}if(o===b){s=A.fb()
b.b1(new A.P(new A.O(!0,o,null,"Cannot complete a future with itself"),s))
return}r=b.a&1
s=o.a=s|r
if((s&24)===0){q=b.c
b.a=b.a&1|4
b.c=o
o.au(q)
return}if(!c)if(b.c==null)o=(s&16)===0||r!==0
else o=!1
else o=!0
if(o){q=b.T()
b.R(p.a)
A.aJ(b,q)
return}b.a^=2
A.eP(null,null,b.b,new A.eh(p,b))},
aJ(a,b){var s,r,q,p,o,n,m,l,k,j,i,h,g={},f=g.a=a
for(;;){s={}
r=f.a
q=(r&16)===0
p=!q
if(b==null){if(p&&(r&1)===0){f=f.c
A.eN(f.a,f.b)}return}s.a=b
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
if(r){A.eN(m.a,m.b)
return}j=$.w
if(j!==k)$.w=k
else j=null
f=f.c
if((f&15)===8)new A.el(s,g,p).$0()
else if(q){if((f&1)!==0)new A.ek(s,m).$0()}else if((f&2)!==0)new A.ej(g,s).$0()
if(j!=null)$.w=j
f=s.c
if(f instanceof A.K){r=s.a.$ti
r=r.i("aW<2>").b(f)||!r.y[1].b(f)}else r=!1
if(r){i=s.a.b
if((f.a&24)!==0){h=i.c
i.c=null
b=i.U(h)
i.a=f.a&30|i.a&1
i.c=f.c
g.a=f
continue}else A.fe(f,i,!0)
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
jt(a,b){if(t.C.b(a))return b.bw(a)
if(t.v.b(a))return a
throw A.f(A.fw(a,"onError",u.c))},
jr(){var s,r
for(s=$.aM;s!=null;s=$.aM){$.bz=null
r=s.b
$.aM=r
if(r==null)$.bx=null
s.a.$0()}},
jy(){$.fl=!0
try{A.jr()}finally{$.bz=null
$.fl=!1
if($.aM!=null)$.fv().$1(A.hm())}},
hk(a){var s=new A.cv(a),r=$.bx
if(r==null){$.aM=$.bx=s
if(!$.fl)$.fv().$1(A.hm())}else $.bx=r.b=s},
jv(a){var s,r,q,p=$.aM
if(p==null){A.hk(a)
$.bz=$.bx
return}s=new A.cv(a)
r=$.bz
if(r==null){s.b=p
$.aM=$.bz=s}else{q=r.b
s.b=q
$.bz=r.b=s
if(q==null)$.bx=s}},
io(a,b){var s=$.w
if(s===B.c)return A.fd(a,b)
return A.fd(a,s.aB(b))},
ip(a,b){var s=$.w
if(s===B.c)return A.fM(a,b)
return A.fM(a,s.bk(b,t.ae))},
eN(a,b){A.jv(new A.eO(a,b))},
hh(a,b,c,d){var s,r=$.w
if(r===c)return d.$0()
$.w=c
s=r
try{r=d.$0()
return r}finally{$.w=s}},
hi(a,b,c,d,e){var s,r=$.w
if(r===c)return d.$1(e)
$.w=c
s=r
try{r=d.$1(e)
return r}finally{$.w=s}},
ju(a,b,c,d,e,f){var s,r=$.w
if(r===c)return d.$2(e,f)
$.w=c
s=r
try{r=d.$2(e,f)
return r}finally{$.w=s}},
eP(a,b,c,d){if(B.c!==c){d=c.aB(d)
d=d}A.hk(d)},
eb:function eb(a){this.a=a},
ea:function ea(a,b,c){this.a=a
this.b=b
this.c=c},
ec:function ec(a){this.a=a},
ed:function ed(a){this.a=a},
br:function br(){this.c=0},
ew:function ew(a,b){this.a=a
this.b=b},
ev:function ev(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
P:function P(a,b){this.a=a
this.b=b},
d6:function d6(a,b,c){this.a=a
this.b=b
this.c=c},
cy:function cy(a,b,c,d,e){var _=this
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
ef:function ef(a,b){this.a=a
this.b=b},
ei:function ei(a,b){this.a=a
this.b=b},
eh:function eh(a,b){this.a=a
this.b=b},
eg:function eg(a,b){this.a=a
this.b=b},
el:function el(a,b,c){this.a=a
this.b=b
this.c=c},
em:function em(a,b){this.a=a
this.b=b},
en:function en(a){this.a=a},
ek:function ek(a,b){this.a=a
this.b=b},
ej:function ej(a,b){this.a=a
this.b=b},
cv:function cv(a){this.a=a
this.b=null},
eA:function eA(){},
es:function es(){},
et:function et(a,b){this.a=a
this.b=b},
eu:function eu(a,b,c){this.a=a
this.b=b
this.c=c},
eO:function eO(a,b){this.a=a
this.b=b},
fQ(a,b){var s=a[b]
return s===a?null:s},
fR(a,b,c){if(c==null)a[b]=a
else a[b]=c},
iu(){var s=Object.create(null)
A.fR(s,"<non-identifier-key>",s)
delete s["<non-identifier-key>"]
return s},
q(a,b,c){return A.jM(a,new A.ad(b.i("@<0>").u(c).i("ad<1,2>")))},
dI(a,b){return new A.ad(a.i("@<0>").u(b).i("ad<1,2>"))},
aA(a){return new A.bi(a.i("bi<0>"))},
ff(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s},
fS(a,b,c){var s=new A.aK(a,b,c.i("aK<0>"))
s.c=a.e
return s},
fH(a){var s,r
if(A.fr(a))return"{...}"
s=new A.cq("")
try{r={}
$.ak.push(a)
s.a+="{"
r.a=!0
a.a9(0,new A.dJ(r,s))
s.a+="}"}finally{$.ak.pop()}r=s.a
return r.charCodeAt(0)==0?r:r},
be:function be(){},
bg:function bg(a){var _=this
_.a=0
_.e=_.d=_.c=_.b=null
_.$ti=a},
bf:function bf(a,b){this.a=a
this.$ti=b},
cz:function cz(a,b,c){var _=this
_.a=a
_.b=b
_.c=0
_.d=null
_.$ti=c},
bi:function bi(a){var _=this
_.a=0
_.f=_.e=_.d=_.c=_.b=null
_.r=0
_.$ti=a},
ep:function ep(a){this.a=a
this.c=this.b=null},
aK:function aK(a,b,c){var _=this
_.a=a
_.b=b
_.d=_.c=null
_.$ti=c},
r:function r(){},
a1:function a1(){},
dJ:function dJ(a,b){this.a=a
this.b=b},
aG:function aG(){},
bp:function bp(){},
jK(a){var s=A.ig(a)
if(s!=null)return s
throw A.f(A.fD("Invalid double",a))},
hZ(a,b){a=A.z(a,new Error())
a.stack=b.j(0)
throw a},
fG(a,b,c,d){var s,r=c?J.i2(a,d):J.i1(a,d)
if(a!==0&&b!=null)for(s=0;s<r.length;++s)r[s]=b
return r},
i9(a,b,c){var s,r,q=A.b([],c.i("t<0>"))
for(s=a.length,r=0;r<a.length;a.length===s||(0,A.M)(a),++r)q.push(a[r])
q.$flags=1
return q},
aC(a,b){var s,r
if(Array.isArray(a))return A.b(a.slice(0),b.i("t<0>"))
s=A.b([],b.i("t<0>"))
for(r=J.cI(a);r.k();)s.push(r.gl())
return s},
ii(a){return new A.dF(a,A.i6(a,!1,!0,!1,!1,""))},
fL(a,b,c){var s=J.cI(b)
if(!s.k())return a
if(c.length===0){do a+=A.o(s.gl())
while(s.k())}else{a+=A.o(s.gl())
while(s.k())a=a+c+A.o(s.gl())}return a},
fb(){return A.an(new Error())},
d1(a){if(typeof a=="number"||A.eM(a)||a==null)return J.bB(a)
if(typeof a=="string")return JSON.stringify(a)
return A.fJ(a)},
i_(a,b){A.hn(a,"error",t.K)
A.hn(b,"stackTrace",t.l)
A.hZ(a,b)},
bF(a){return new A.bE(a)},
aQ(a,b){return new A.O(!1,null,b,a)},
fw(a,b,c){return new A.O(!0,a,b,c)},
dR(a,b,c,d,e){return new A.ch(b,c,!0,a,d,"Invalid value")},
ih(a,b,c){if(0>a||a>c)throw A.f(A.dR(a,0,c,"start",null))
if(b!=null){if(a>b||b>c)throw A.f(A.dR(b,a,c,"end",null))
return b}return c},
bd(a){return new A.bc(a)},
fO(a){return new A.cs(a)},
im(a){return new A.co(a)},
Q(a){return new A.bI(a)},
fC(a){return new A.ee(a)},
fD(a,b){return new A.d5(a,b)},
i0(a,b,c){var s,r
if(A.fr(a)){if(b==="("&&c===")")return"(...)"
return b+"..."+c}s=A.b([],t.s)
$.ak.push(a)
try{A.jn(a,s)}finally{$.ak.pop()}r=A.fL(b,s,", ")+c
return r.charCodeAt(0)==0?r:r},
f7(a,b,c){var s,r
if(A.fr(a))return b+"..."+c
s=new A.cq(b)
$.ak.push(a)
try{r=s
r.a=A.fL(r.a,a,", ")}finally{$.ak.pop()}s.a+=c
r=s.a
return r.charCodeAt(0)==0?r:r},
jn(a,b){var s,r,q,p,o,n,m,l=a.gq(a),k=0,j=0
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
ib(a,b,c,d){var s
if(B.l===c){s=B.b.gm(a)
b=J.N(b)
return A.fc(A.a2(A.a2($.f1(),s),b))}if(B.l===d){s=B.b.gm(a)
b=J.N(b)
c=J.N(c)
return A.fc(A.a2(A.a2(A.a2($.f1(),s),b),c))}s=B.b.gm(a)
b=J.N(b)
c=J.N(c)
d=J.N(d)
d=A.fc(A.a2(A.a2(A.a2(A.a2($.f1(),s),b),c),d))
return d},
hv(a){A.jX(a)},
aw:function aw(a){this.a=a},
p:function p(){},
bE:function bE(a){this.a=a},
U:function U(){},
O:function O(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
ch:function ch(a,b,c,d,e,f){var _=this
_.e=a
_.f=b
_.a=c
_.b=d
_.c=e
_.d=f},
bc:function bc(a){this.a=a},
cs:function cs(a){this.a=a},
co:function co(a){this.a=a},
bI:function bI(a){this.a=a},
cb:function cb(){},
ba:function ba(){},
ee:function ee(a){this.a=a},
d5:function d5(a,b){this.a=a
this.b=b},
e:function e(){},
ag:function ag(a,b,c){this.a=a
this.b=b
this.$ti=c},
B:function B(){},
j:function j(){},
cB:function cB(){},
dZ:function dZ(){this.b=this.a=0},
cq:function cq(a){this.a=a},
cD(a){var s
if(typeof a=="function")throw A.f(A.aQ("Attempting to rewrap a JS function.",null))
s=function(b,c){return function(d){return b(c,d,arguments.length)}}(A.j1,a)
s[$.ft()]=a
return s},
j1(a,b,c){if(c>=1)return a.$1(b)
return a.$0()},
hf(a){return a==null||A.eM(a)||typeof a=="number"||typeof a=="string"||t.U.b(a)||t.bX.b(a)||t.ca.b(a)||t.d.b(a)||t.c0.b(a)||t.k.b(a)||t.bk.b(a)||t.B.b(a)||t.q.b(a)||t.J.b(a)||t.Y.b(a)},
bA(a){if(A.hf(a))return a
return new A.eX(new A.bg(t.A)).$1(a)},
eX:function eX(a){this.a=a},
as:function as(a){this.b=a},
hd(a,b){var s=b.a
if(s===0)return null
return b},
a6(a,b,c,d,e,f,g){var s=!1
if(c==null)s=d==null
if(s)return null
s=A.dI(t.N,t.co)
if(c!=null)s.t(0,"click",c)
if(d!=null)s.t(0,"input",d)
return s},
d(a,b){var s=null
return new A.R("div",s,b,s,s,A.a6(s,s,s,s,s,s,s),a)},
a(a,b){var s=null
return new A.aH("span",b,a,s,s,A.a6(s,s,s,s,s,s,s),B.a)},
ah(a,b){var s=null
return new A.cc("p",b,a,s,s,A.a6(s,s,s,s,s,s,s),B.a)},
d7(a,b){var s=null
return new A.bN("h2",b,a,s,s,A.a6(s,s,s,s,s,s,s),B.a)},
f5(a,b){var s=null
return new A.bO("h3",b,a,s,s,A.a6(s,s,s,s,s,s,s),B.a)},
D(a,b,c,d){var s=null
return new A.au("button",d,b,s,s,A.a6(s,s,c,s,s,s,s),a)},
f6(a,b,c,d,e){var s=null,r=t.N
r=A.dI(r,r)
r.t(0,"placeholder",c)
if(e!=null)r.t(0,"value",e)
if(d!=null)r.t(0,"type",d)
return new A.bQ("input",s,a,s,A.hd(s,r),A.a6(s,s,s,b,s,s,s),B.a)},
ar(a,b,c,d){var s=null,r=t.N
r=A.dI(r,r)
r.t(0,"href",c)
return new A.bC("a",d,b,s,A.hd(s,r),A.a6(s,s,s,s,s,s,s),a)},
cl(a,b,c){return new A.ck("section",null,c,null,a,null,b)},
dN(a,b){var s=null
return new A.ce("pre",s,b,s,s,s,a)},
l:function l(){},
aS:function aS(){},
aV:function aV(){},
bZ:function bZ(){},
aU:function aU(){},
ci:function ci(){},
ab:function ab(a){this.a=a},
A:function A(a){this.a=a},
ay:function ay(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.$ti=d},
x:function x(a){this.a=a},
R:function R(a,b,c,d,e,f,g){var _=this
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
cc:function cc(a,b,c,d,e,f,g){var _=this
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
bN:function bN(a,b,c,d,e,f,g){var _=this
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
au:function au(a,b,c,d,e,f,g){var _=this
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
bC:function bC(a,b,c,d,e,f,g){var _=this
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
bL:function bL(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
c_:function c_(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
ca:function ca(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g},
ck:function ck(a,b,c,d,e,f,g){var _=this
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
jW(a,b){var s,r,q=A.aA(t.M),p=A.cE(a,new A.bo(q))
for(s=p.length,r=0;r<p.length;p.length===s||(0,A.M)(p),++r)b.appendChild(p[r])
A.aC(q,q.$ti.c)
return new A.cV()},
cE(a5,a6){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2=null,a3=a5 instanceof A.x,a4=a3?a5.a:a2
if(a3){s=v.G.document.createElement("span")
s.innerHTML=a4
return A.b([s],t.O)}r=a5 instanceof A.aS
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
if(n!=null)for(h=new A.ae(n,A.a5(n).i("ae<1,2>")).gq(0);h.k();){g=h.d
i.setAttribute(g.a,g.b)}if(m!=null)for(h=new A.ae(m,A.a5(m).i("ae<1,2>")).gq(0);h.k();){f=h.d
A.iZ(i,f.a,f.b)}if(p!=null)i.appendChild(a3.document.createTextNode(p))
for(a3=l.length,e=0;e<l.length;l.length===a3||(0,A.M)(l),++e){d=A.cE(l[e],a6)
for(h=d.length,c=0;c<d.length;d.length===h||(0,A.M)(d),++c)i.appendChild(d[c])}return A.b([i],t.O)}b=a5 instanceof A.aV
if(b)l=a5.a
else l=a2
if(b){a=A.b([],t.O)
for(a3=l.length,e=0;e<l.length;l.length===a3||(0,A.M)(l),++e)B.h.aA(a,A.cE(l[e],a6))
return a}a3=a5 instanceof A.A
a0=a3?a5.a:a2
if(a3){a1=v.G.document.createElement("span")
a1.setAttribute("data-bloom-live","")
A.j0(a1,a6,a0,a2)
return A.b([a1],t.O)}if(a5 instanceof A.ay){a1=v.G.document.createElement("span")
a1.setAttribute("data-bloom-foreach","")
A.j_(a1,a6,a5)
return A.b([a1],t.O)}},
j_(a,b,c){var s=A.dI(t.N,t.cl)
b.a.D(0,new A.eD(A.hp(new A.eE(new A.eF(c,c.c,s,a))),s))},
j0(a,b,c,d){var s=new A.bo(A.aA(t.M))
b.a.D(0,new A.eH(A.hp(new A.eI(new A.eJ(s,c,d,a))),s))},
iZ(a,b,c){a.addEventListener(b,A.cD(new A.eB(b,c)))},
jD(a,b){var s,r,q,p=null,o=null
try{s=b.target
if(s!=null){r=s
p=A.jp(r,"value")
o=A.jo(r,"checked")}}catch(q){}return new A.as(p)},
jp(a,b){var s,r,q
try{s=v.G.Reflect.get(a,b)
if(s==null)return null
if(s!=null&&typeof s==="string"){r=A.h5(s)
return r}return null}catch(q){return null}},
jo(a,b){var s,r,q
try{s=v.G.Reflect.get(a,b)
if(s==null)return null
if(s!=null&&typeof s==="boolean"){r=A.h4(s)
return r}return null}catch(q){return null}},
cV:function cV(){},
bo:function bo(a){this.a=a},
bh:function bh(a,b){this.b=a
this.c=b},
eF:function eF(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
eG:function eG(a){this.a=a},
eE:function eE(a){this.a=a},
eD:function eD(a,b){this.a=a
this.b=b},
eJ:function eJ(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.d=d},
eI:function eI(a){this.a=a},
eH:function eH(a,b){this.a=a
this.b=b},
eB:function eB(a,b){this.a=a
this.b=b},
cK:function cK(a){this.a=a},
cO:function cO(a){this.a=a},
cM:function cM(a){this.a=a},
cN:function cN(a){this.a=a},
cP:function cP(a){this.a=a},
cQ:function cQ(a){this.a=a},
cR:function cR(a){this.a=a},
cS:function cS(a){this.a=a},
cT:function cT(a){this.a=a},
cU:function cU(a){this.a=a},
cL:function cL(){},
cW:function cW(a){this.a=a},
cZ:function cZ(a){this.a=a},
d_:function d_(a){this.a=a},
cY:function cY(a,b,c){this.a=a
this.b=b
this.c=c},
cX:function cX(a,b){this.a=a
this.b=b},
d2:function d2(){},
d8:function d8(a){this.a=a},
da:function da(a){this.a=a},
d9:function d9(a){this.a=a},
de:function de(a,b,c,d,e,f,g){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=$
_.r=f
_.w=g
_.y=_.x=$},
dC:function dC(a){this.a=a},
dB:function dB(a){this.a=a},
dD:function dD(a){this.a=a},
dA:function dA(a){this.a=a},
dq:function dq(a,b,c){this.a=a
this.b=b
this.c=c},
dp:function dp(a,b){this.a=a
this.b=b},
dv:function dv(a){this.a=a},
dw:function dw(a){this.a=a},
dx:function dx(a){this.a=a},
dy:function dy(a){this.a=a},
dt:function dt(a,b){this.a=a
this.b=b},
ds:function ds(a){this.a=a},
du:function du(a,b){this.a=a
this.b=b},
dr:function dr(a){this.a=a},
dz:function dz(){},
dh:function dh(a){this.a=a},
di:function di(a){this.a=a},
dj:function dj(a){this.a=a},
dk:function dk(a){this.a=a},
dl:function dl(a){this.a=a},
dm:function dm(a){this.a=a},
dn:function dn(a){this.a=a},
df:function df(){},
dg:function dg(){},
dK:function dK(a){this.a=a},
dL:function dL(a){this.a=a},
jU(){var s,r,q,p=null,o="hover:text-white transition-colors",n=$.hB(),m=t.S,l=t.N,k=new A.d2(),j=t.t,i=A.d(A.b([new A.dK(n).A(),new A.c_("main",p,"flex-1 flex flex-col",p,p,p,A.b([new A.d8(n).A(),new A.cK(n).A(),new A.de(n,A.G(0,m),A.G(A.b([new A.a3(!0,"1","Build fine-grained Web app in Dart"),new A.a3(!0,"2","Vendor NPM packages with Bun"),new A.a3(!1,"3","Deploy to Cloudflare edge in <1ms")],t.f),t.w),A.G("",l),A.G(42,m),A.G("",l),A.G("",l)).A(),A.cl(A.q(["id","features"],l,l),A.b([A.d(A.b([A.a(u.a,"Core Architecture"),A.d7(u.d,"Engineered for Zero Overhead"),A.ah("text-zinc-400 text-base leading-relaxed","A web-first framework written in Dart that compiles pure AST descriptors directly to the DOM and server SSR without canvas or virtual DOM bloat.")],j),"text-center max-w-3xl mx-auto mb-16"),A.d(A.b([k.P("The exact same Dart AST descriptors execute in <1ms on server isolates to output SEO-optimized static HTML, then seamlessly activate fine-grained signal subscriptions in the browser.",'<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>',"Sub-Millisecond","Dual-Backend SSR & Instant Hydration"),k.P("ForEachNode uses active key registries to reuse existing DOM elements on list updates, preserving input focus, scroll positions, and native CSS transitions during high-throughput mutations.",'<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16"/>',"Zero DOM Tear-down","Keyed DOM List Reconciliation"),k.P("Consume any of the 2.5M+ NPM packages surgically. The Bloom CLI runs Bun to extract ESM bundles into web/vendor/ and manages browser import maps automatically with CDN fallback.",'<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>',"NPM Native","Bun ESM Toolchain Orchestration"),k.P("Organize pages naturally in lib/routes/ with automatic parameter parsing ([slug].dart), nested layout cascades (_layout.dart), and dedicated 404 boundaries (_error.dart).",'<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6 3V7m6 10l4.553 2.276A1 1 0 0021 18.382V7.618a1 1 0 00-.553-.894L15 4m0 13V4m0 0L9 7"/>',"Standardized DX","Next.js File-Based Page Routing")],j),"grid grid-cols-1 md:grid-cols-2 gap-6")],j),"py-20 px-6 max-w-7xl mx-auto"),new A.cW(n).A()],j)),new A.bL("footer",p,"w-full border-t border-[#1E1E24] bg-[#060608] py-12 px-6",p,p,p,A.b([A.d(A.b([A.d(A.b([A.a("font-semibold text-zinc-300 font-mono","Bloom JS Native"),A.a("text-zinc-600","\u2022"),A.a(p,"MIT Open Source Framework")],j),"flex items-center gap-4"),A.d(A.b([A.a("w-2 h-2 rounded-full bg-emerald-500 animate-pulse",p),A.a(p,"Runtime Status: Nominal (<1ms SSR)")],j),"inline-flex items-center gap-2 px-3 py-1 rounded-full bg-[#101014] border border-[#1E1E24] text-xs font-mono text-emerald-400"),A.d(A.b([A.ar(B.a,o,"https://github.com/Chidi09/Bloom","GitHub"),A.ar(B.a,o,"https://github.com/Chidi09/Bloom/tree/main/packages/bloom_js_native","Docs")],j),"flex items-center gap-6")],j),"max-w-7xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-6 text-sm text-zinc-500")],j)),new A.A(new A.eY(n))],j),"min-h-screen bg-[#09090B] text-zinc-100 flex flex-col justify-between selection:bg-indigo-600 selection:text-white relative")
j=v.G
s=j.document.querySelector("#app")
if(s==null)A.f0(A.im('Bloom mount: selector "#app" matched no element.'))
A.jW(i,s)
r=j.document.getElementById("three-hero-canvas")
if(r!=null)new A.e_(r).bq()
q=j.document.getElementById("perf-chart")
if(q!=null)A.hT(q)},
eY:function eY(a){this.a=a},
e_:function e_(a){var _=this
_.a=a
_.b=!1
_.d=_.c=0},
e1:function e1(a){this.a=a},
e0:function e0(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
e2:function e2(a,b,c){this.a=a
this.b=b
this.c=c},
ik(){var s,r,q=A.G("main.dart",t.N),p=t.S,o=A.G(24,p),n=A.G(60,p),m=A.G(0.12,t.i),l=J.dE(24,p)
for(s=0;s<24;s=r){r=s+1
l[s]=r}p=t.y
p=new A.dT(q,o,n,m,A.G(l,t.L),A.G(!1,p),A.G(null,t.u),A.G(!1,p))
p.bh()
return p},
dT:function dT(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
dX:function dX(a){this.a=a},
dW:function dW(a,b){this.a=a
this.b=b},
dV:function dV(a){this.a=a},
dU:function dU(){},
fj(){var s,r,q,p,o,n,m=$.X
if(m>1){$.X=m-1
return}s=null
r=!1
while(m=$.eC,m!=null){q=m
$.eC=null
$.eK=$.eK+1
while(q!=null){o=q.f
q.f=null
q.r&=4294967293
if((q.r&8)===0&&A.he(q))try{q.ah()}catch(n){p=A.a9(n)
if(!r){s=p
r=!0}}q=o}}$.eK=0
$.X=$.X-1
if(r)throw A.f(s)},
fo(a,b){var s=$.eL,r=$.by+1
$.by=r
return new A.aR(a,s-1,!1,null,r,A.aA(t.M),b.i("aR<0>"))},
hp(a){var s,r=$.by+1
$.by=r
s=new A.bJ(a,null,r,A.aA(t.M))
s.aW(a,null)
return s.gbm()},
il(a,b,c,d){var s=$.by+1
$.by=s
s=new A.b9(a,new A.dY(d),!1,c,s,A.aA(t.M),d.i("b9<0>"))
s.z=a
return s},
G(a,b){return A.il(a,!1,null,b)},
h2(a){var s,r,q,p=null,o=$.C
if(o==null)return p
s=a.f
if(s==null||s.d!==o){o=o.gp()
r=$.C
s=new A.eq(a,o,p,r,p,p,0,s)
if(r.gp()!=null)$.C.gp().c=s
$.C.sp(s)
a.f=s
if(($.C.gam()&32)!==0)a.W(s)
return s}else if(s.r===-1){s.r=0
r=s.c
if(r!=null){r.b=s.b
q=s.b
if(q!=null)q.c=r
s.b=o.gp()
s.c=null
$.C.gp().c=s
$.C.sp(s)}return s}return p},
he(a){var s,r
for(s=a.gp();s!=null;s=s.c){r=s.a
if(r.e!==s.r||!r.a5()||r.e!==s.r)return!0}return!1},
hg(a){var s,r,q,p
for(s=a.gp();s!=null;s=p){r=s.a
q=r.f
if(q!=null)s.w=q
r.f=s
s.r=-1
p=s.c
if(p==null){a.sp(s)
break}}},
h7(a){var s,r,q,p,o=a.gp()
for(s=null;o!=null;o=r){r=o.b
if(o.r===-1){o.a.I(o)
if(r!=null)r.c=o.c
q=o.c
if(q!=null)q.b=r}else s=o
q=o.a
p=o.w
q.f=p
if(p!=null)o.w=null}a.sp(s)},
h6(a){var s,r,q=a.d
a.d=null
if(q!=null){$.X=$.X+1
s=$.C
$.C=null
try{q.$0()}catch(r){a.r=(a.r&=4294967294)|8
A.fi(a)
throw r}finally{$.C=s
A.fj()}}},
fi(a){var s
for(s=a.e;s!=null;s=s.c)s.a.I(s)
a.e=a.a=null
A.h6(a)},
aR:function aR(a,b,c,d,e,f,g){var _=this
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
bJ:function bJ(a,b,c,d){var _=this
_.a=a
_.b=b
_.c=c
_.f=_.e=_.d=null
_.r=32
_.w=d
_.x=!1},
d0:function d0(a,b){this.a=a
this.b=b},
aF:function aF(){},
b9:function b9(a,b,c,d,e,f,g){var _=this
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
dY:function dY(a){this.a=a},
eq:function eq(a,b,c,d,e,f,g,h){var _=this
_.a=a
_.b=b
_.c=c
_.d=d
_.e=e
_.f=f
_.r=g
_.w=h},
cm:function cm(){},
cn:function cn(a){this.a=a},
ax:function ax(){},
hy(a){return v.mangledGlobalNames[a]},
jX(a){if(typeof dartPrint=="function"){dartPrint(a)
return}if(typeof console=="object"&&typeof console.log!="undefined"){console.log(a)
return}if(typeof print=="function"){print(a)
return}throw"Unable to print message: "+String(a)},
jZ(a){throw A.z(A.i7(a),new Error())},
a8(){throw A.z(A.i8(""),new Error())},
hT(a){var s,r,q,p,o,n,m="rgba(255, 255, 255, 0.05)"
try{r=t.n
q=t.N
p=t.K
o=t.D
s=A.aL(A.bA(A.q(["type","bar","data",A.q(["labels",A.b(["Bloom JS Native","Next.js (React 19)","Nuxt 3 (Vue 3)","Angular SSR","SvelteKit"],t.s),"datasets",A.b([A.q(["label","SSR Response Time (ms) \u2014 Lower is better","data",A.b([0.4,18.2,14.5,26,6.8],r),"backgroundColor","rgba(99, 102, 241, 0.85)","borderColor","rgba(99, 102, 241, 1)","borderWidth",1,"borderRadius",6],q,p),A.q(["label","Client Bundle Baseline (kB gzip) \u2014 Lower is better","data",A.b([20.1,98.4,62,145,28.5],r),"backgroundColor","rgba(139, 92, 246, 0.75)","borderColor","rgba(139, 92, 246, 1)","borderWidth",1,"borderRadius",6],q,p)],t.x)],q,t.r),"options",A.q(["responsive",!0,"maintainAspectRatio",!1,"plugins",A.q(["legend",A.q(["labels",A.q(["color","#A1A1AA","font",A.q(["family","JetBrains Mono","size",11],q,p)],q,p)],q,o),"tooltip",A.q(["backgroundColor","#14141A","titleColor","#FFFFFF","bodyColor","#A1A1AA","borderColor","#27272A","borderWidth",1],q,p)],q,o),"scales",A.q(["x",A.q(["grid",A.q(["color",m],q,q),"ticks",A.q(["color","#A1A1AA","font",A.q(["family","Plus Jakarta Sans","size",12,"weight","600"],q,p)],q,p)],q,o),"y",A.q(["grid",A.q(["color",m],q,q),"ticks",A.q(["color","#71717A","font",A.q(["family","JetBrains Mono","size",11],q,p)],q,p)],q,o)],q,t.E)],q,p)],q,t.z)))
v.G.Chart(a,s)}catch(n){}},
av(a,b){var s,r,q
try{r=t.N
s=A.aL(A.bA(A.q(["particleCount",60,"spread",70,"origin",A.q(["x",a,"y",b],r,t.i),"colors",A.b(["#6366F1","#8B5CF6","#3B82F6","#10B981"],t.s),"disableForReducedMotion",!0],r,t.z)))
v.G.confetti(s)}catch(q){}}},B={}
var w=[A,J,B]
var $={}
A.f8.prototype={}
J.bR.prototype={
F(a,b){return a===b},
gm(a){return A.cf(a)},
j(a){return"Instance of '"+A.cg(a)+"'"},
gn(a){return A.al(A.fk(this))}}
J.bT.prototype={
j(a){return String(a)},
gm(a){return a?519018:218159},
gn(a){return A.al(t.y)},
$im:1,
$iv:1}
J.aY.prototype={
F(a,b){return null==b},
j(a){return"null"},
gm(a){return 0},
$im:1,
$iB:1}
J.b0.prototype={$iu:1}
J.a_.prototype={
gm(a){return 0},
j(a){return String(a)}}
J.cd.prototype={}
J.bb.prototype={}
J.Z.prototype={
j(a){var s=a[$.hA()]
if(s==null)s=a[$.ft()]
if(s==null)return this.aT(a)
return"JavaScript function for "+J.bB(s)},
$iac:1}
J.b_.prototype={
gm(a){return 0},
j(a){return String(a)}}
J.b1.prototype={
gm(a){return 0},
j(a){return String(a)}}
J.t.prototype={
D(a,b){a.$flags&1&&A.hx(a,29)
a.push(b)},
aN(a,b){return new A.W(a,b,A.cC(a).i("W<1>"))},
aA(a,b){var s
a.$flags&1&&A.hx(a,"addAll",2)
if(Array.isArray(b)){this.b0(a,b)
return}for(s=J.cI(b);s.k();)a.push(s.gl())},
b0(a,b){var s,r=b.length
if(r===0)return
if(a===b)throw A.f(A.Q(a))
for(s=0;s<r;++s)a.push(b[s])},
J(a,b,c){return new A.T(a,b,A.cC(a).i("@<1>").u(c).i("T<1,2>"))},
bu(a,b){var s,r=A.fG(a.length,"",!1,t.N)
for(s=0;s<a.length;++s)r[s]=A.o(a[s])
return r.join(b)},
Y(a,b){return a[b]},
j(a){return A.f7(a,"[","]")},
gq(a){return new J.bD(a,a.length,A.cC(a).i("bD<1>"))},
gm(a){return A.cf(a)},
gB(a){return a.length},
$ii:1,
$ie:1,
$ik:1}
J.bS.prototype={
bJ(a){var s,r,q
if(!Array.isArray(a))return null
s=a.$flags|0
if((s&4)!==0)r="const, "
else if((s&2)!==0)r="unmodifiable, "
else r=(s&1)!==0?"fixed, ":""
q="Instance of '"+A.cg(a)+"'"
if(r==="")return q
return q+" ("+r+"length: "+a.length+")"}}
J.dG.prototype={}
J.bD.prototype={
gl(){var s=this.d
return s==null?this.$ti.c.a(s):s},
k(){var s,r=this,q=r.a,p=q.length
if(r.b!==p)throw A.f(A.M(q))
s=r.c
if(s>=p){r.d=null
return!1}r.d=q[s]
r.c=s+1
return!0}}
J.aZ.prototype={
a7(a,b){var s
if(a<b)return-1
else if(a>b)return 1
else if(a===b){if(a===0){s=B.b.gZ(b)
if(this.gZ(a)===s)return 0
if(this.gZ(a))return-1
return 1}return 0}else if(isNaN(a)){if(isNaN(b))return 0
return 1}else return-1},
gZ(a){return a===0?1/a<0:a<0},
bo(a){var s,r
if(a>=0){if(a<=2147483647)return a|0}else if(a>=-2147483648){s=a|0
return a===s?s:s-1}r=Math.floor(a)
if(isFinite(r))return r
throw A.f(A.bd(""+a+".floor()"))},
aC(a,b,c){if(B.b.a7(b,c)>0)throw A.f(A.jE(b))
if(this.a7(a,b)<0)return b
if(this.a7(a,c)>0)return c
return a},
bI(a,b){var s
if(b>20)throw A.f(A.dR(b,0,20,"fractionDigits",null))
s=a.toFixed(b)
if(a===0&&this.gZ(a))return"-"+s
return s},
j(a){if(a===0&&1/a<0)return"-0.0"
else return""+a},
gm(a){var s,r,q,p,o=a|0
if(a===o)return o&536870911
s=Math.abs(a)
r=Math.log(s)/0.6931471805599453|0
q=Math.pow(2,r)
p=s<1?s/q:q/s
return((p*9007199254740992|0)+(p*3542243181176521|0))*599197+r*1259&536870911},
O(a,b){return a-b},
ac(a,b){var s=a%b
if(s===0)return 0
if(s>0)return s
return s+b},
aV(a,b){if((a|0)===a)if(b>=1)return a/b|0
return this.aw(a,b)},
av(a,b){return(a|0)===a?a/b|0:this.aw(a,b)},
aw(a,b){var s=a/b
if(s>=-2147483648&&s<=2147483647)return s|0
if(s>0){if(s!==1/0)return Math.floor(s)}else if(s>-1/0)return Math.ceil(s)
throw A.f(A.bd("Result of truncating division is "+A.o(s)+": "+A.o(a)+" ~/ "+b))},
bf(a,b){var s
if(a>0)s=this.be(a,b)
else{s=b>31?31:b
s=a>>s>>>0}return s},
be(a,b){return b>31?0:a>>>b},
gn(a){return A.al(t.H)},
$in:1}
J.aX.prototype={
gn(a){return A.al(t.S)},
$im:1,
$ic:1}
J.bU.prototype={
gn(a){return A.al(t.i)},
$im:1}
J.az.prototype={
aS(a,b,c){return a.substring(b,A.ih(b,c,a.length))},
aL(a){var s,r,q,p=a.trim(),o=p.length
if(o===0)return p
if(p.charCodeAt(0)===133){s=J.i4(p,1)
if(s===o)return""}else s=0
r=o-1
q=p.charCodeAt(r)===133?J.i5(p,r):o
if(s===0&&q===o)return p
return p.substring(s,q)},
aP(a,b){var s,r
if(0>=b)return""
if(b===1||a.length===0)return a
if(b!==b>>>0)throw A.f(B.v)
for(s=a,r="";;){if((b&1)===1)r=s+r
b=b>>>1
if(b===0)break
s+=s}return r},
aJ(a,b,c){var s=b-a.length
if(s<=0)return a
return this.aP(c,s)+a},
j(a){return a},
gm(a){var s,r,q
for(s=a.length,r=0,q=0;q<s;++q){r=r+a.charCodeAt(q)&536870911
r=r+((r&524287)<<10)&536870911
r^=r>>6}r=r+((r&67108863)<<3)&536870911
r^=r>>11
return r+((r&16383)<<15)&536870911},
gn(a){return A.al(t.N)},
$im:1,
$ih:1}
A.b2.prototype={
j(a){return"LateInitializationError: "+this.a}}
A.dS.prototype={}
A.i.prototype={}
A.I.prototype={
gq(a){return new A.aB(this,this.gB(0),this.$ti.i("aB<I.E>"))},
J(a,b,c){return new A.T(this,b,this.$ti.i("@<I.E>").u(c).i("T<1,2>"))}}
A.aB.prototype={
gl(){var s=this.d
return s==null?this.$ti.c.a(s):s},
k(){var s,r=this,q=r.a,p=J.hq(q),o=p.gB(q)
if(r.b!==o)throw A.f(A.Q(q))
s=r.c
if(s>=o){r.d=null
return!1}r.d=p.Y(q,s);++r.c
return!0}}
A.S.prototype={
gq(a){var s=this.a
return new A.c0(s.gq(s),this.b,A.a5(this).i("c0<1,2>"))}}
A.aa.prototype={$ii:1}
A.c0.prototype={
k(){var s=this,r=s.b
if(r.k()){s.a=s.c.$1(r.gl())
return!0}s.a=null
return!1},
gl(){var s=this.a
return s==null?this.$ti.y[1].a(s):s}}
A.T.prototype={
gB(a){return J.hO(this.a)},
Y(a,b){return this.b.$1(J.hN(this.a,b))}}
A.W.prototype={
gq(a){return new A.cu(J.cI(this.a),this.b)},
J(a,b,c){return new A.S(this,b,this.$ti.i("@<1>").u(c).i("S<1,2>"))}}
A.cu.prototype={
k(){var s,r
for(s=this.a,r=this.b;s.k();)if(r.$1(s.gl()))return!0
return!1},
gl(){return this.a.gl()}}
A.aT.prototype={
sB(a,b){throw A.f(A.bd("Cannot change the length of a fixed-length list"))},
D(a,b){throw A.f(A.bd("Cannot add to a fixed-length list"))}}
A.a3.prototype={$r:"+done,id,text(1,2,3)",$s:1}
A.dO.prototype={
$0(){return B.e.bo(1000*this.a.now())},
$S:7}
A.b8.prototype={}
A.e4.prototype={
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
A.b7.prototype={
j(a){return"Null check operator used on a null value"}}
A.bV.prototype={
j(a){var s,r=this,q="NoSuchMethodError: method not found: '",p=r.b
if(p==null)return"NoSuchMethodError: "+r.a
s=r.c
if(s==null)return q+p+"' ("+r.a+")"
return q+p+"' on '"+s+"' ("+r.a+")"}}
A.ct.prototype={
j(a){var s=this.a
return s.length===0?"Error":"Error: "+s}}
A.dM.prototype={
j(a){return"Throw of null ('"+(this.a===null?"null":"undefined")+"' from JavaScript)"}}
A.bK.prototype={}
A.bq.prototype={
j(a){var s,r=this.b
if(r!=null)return r
r=this.a
s=r!==null&&typeof r==="object"?r.stack:null
return this.b=s==null?"":s},
$iaI:1}
A.Y.prototype={
j(a){var s=this.constructor,r=s==null?null:s.name
return"Closure '"+A.hz(r==null?"unknown":r)+"'"},
$iac:1,
gbK(){return this},
$C:"$1",
$R:1,
$D:null}
A.bG.prototype={$C:"$0",$R:0}
A.bH.prototype={$C:"$2",$R:2}
A.cr.prototype={}
A.cp.prototype={
j(a){var s=this.$static_name
if(s==null)return"Closure of unknown static method"
return"Closure '"+A.hz(s)+"'"}}
A.at.prototype={
F(a,b){if(b==null)return!1
if(this===b)return!0
if(!(b instanceof A.at))return!1
return this.$_target===b.$_target&&this.a===b.a},
gm(a){return(A.f_(this.a)^A.cf(this.$_target))>>>0},
j(a){return"Closure '"+this.$_name+"' of "+("Instance of '"+A.cg(this.a)+"'")}}
A.cj.prototype={
j(a){return"RuntimeError: "+this.a}}
A.ad.prototype={
gaa(){return new A.af(this,A.a5(this).i("af<1>"))},
a8(a){var s=this.b
if(s==null)return!1
return s[a]!=null},
G(a,b){var s,r,q,p,o=null
if(typeof b=="string"){s=this.b
if(s==null)return o
r=s[b]
q=r==null?o:r.b
return q}else if(typeof b=="number"&&(b&0x3fffffff)===b){p=this.c
if(p==null)return o
r=p[b]
q=r==null?o:r.b
return q}else return this.br(b)},
br(a){var s,r,q=this.d
if(q==null)return null
s=this.aZ(q,a)
r=this.aF(s,a)
if(r<0)return null
return s[r].b},
t(a,b,c){var s,r,q=this
if(typeof b=="string"){s=q.b
q.ae(s==null?q.b=q.a3():s,b,c)}else if(typeof b=="number"&&(b&0x3fffffff)===b){r=q.c
q.ae(r==null?q.c=q.a3():r,b,c)}else q.bs(b,c)},
bs(a,b){var s,r,q,p=this,o=p.d
if(o==null)o=p.d=p.a3()
s=p.aE(a)
r=o[s]
if(r==null)o[s]=[p.a0(a,b)]
else{q=p.aF(r,a)
if(q>=0)r[q].b=b
else r.push(p.a0(a,b))}},
by(a,b){var s=this.bb(this.b,b)
return s},
a9(a,b){var s=this,r=s.e,q=s.r
while(r!=null){b.$2(r.a,r.b)
if(q!==s.r)throw A.f(A.Q(s))
r=r.c}},
ae(a,b,c){var s=a[b]
if(s==null)a[b]=this.a0(b,c)
else s.b=c},
bb(a,b){var s
if(a==null)return null
s=a[b]
if(s==null)return null
this.bj(s)
delete a[b]
return s.b},
a_(){this.r=this.r+1&1073741823},
a0(a,b){var s,r=this,q=new A.dH(a,b)
if(r.e==null)r.e=r.f=q
else{s=r.f
s.toString
q.d=s
r.f=s.c=q}++r.a
r.a_()
return q},
bj(a){var s=this,r=a.d,q=a.c
if(r==null)s.e=q
else r.c=q
if(q==null)s.f=r
else q.d=r;--s.a
s.a_()},
aE(a){return J.N(a)&1073741823},
aZ(a,b){return a[this.aE(b)]},
aF(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.aq(a[r].a,b))return r
return-1},
j(a){return A.fH(this)},
a3(){var s=Object.create(null)
s["<non-identifier-key>"]=s
delete s["<non-identifier-key>"]
return s}}
A.dH.prototype={}
A.af.prototype={
gq(a){var s=this.a
return new A.bX(s,s.r,s.e)}}
A.bX.prototype={
gl(){return this.d},
k(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.f(A.Q(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=s.a
r.c=s.c
return!0}}}
A.bY.prototype={
gl(){return this.d},
k(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.f(A.Q(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=s.b
r.c=s.c
return!0}}}
A.ae.prototype={
gq(a){var s=this.a
return new A.bW(s,s.r,s.e,this.$ti.i("bW<1,2>"))}}
A.bW.prototype={
gl(){var s=this.d
s.toString
return s},
k(){var s,r=this,q=r.a
if(r.b!==q.r)throw A.f(A.Q(q))
s=r.c
if(s==null){r.d=null
return!1}else{r.d=new A.ag(s.a,s.b,r.$ti.i("ag<1,2>"))
r.c=s.c
return!0}}}
A.eT.prototype={
$1(a){return this.a(a)},
$S:12}
A.eU.prototype={
$2(a,b){return this.a(a,b)},
$S:13}
A.eV.prototype={
$1(a){return this.a(a)},
$S:14}
A.bn.prototype={
j(a){return this.az(!1)},
az(a){var s,r,q,p,o,n=this.b8(),m=this.ao(),l=(a?"Record ":"")+"("
for(s=n.length,r="",q=0;q<s;++q,r=", "){l+=r
p=n[q]
if(typeof p=="string")l=l+p+": "
o=m[q]
l=a?l+A.fJ(o):l+A.o(o)}l+=")"
return l.charCodeAt(0)==0?l:l},
b8(){var s,r=this.$s
while($.er.length<=r)$.er.push(null)
s=$.er[r]
if(s==null){s=this.b3()
$.er[r]=s}return s},
b3(){var s,r,q,p=this.$r,o=p.indexOf("("),n=p.substring(1,o),m=p.substring(o),l=m==="()"?0:m.replace(/[^,]/g,"").length+1,k=t.K,j=J.dE(l,k)
for(s=0;s<l;++s)j[s]=s
if(n!==""){r=n.split(",")
s=r.length
for(q=l;s>0;){--q;--s
j[q]=r[s]}}j=A.i9(j,!1,k)
j.$flags=3
return j}}
A.cA.prototype={
ao(){return[this.a,this.b,this.c]},
F(a,b){var s=this
if(b==null)return!1
return b instanceof A.cA&&s.$s===b.$s&&J.aq(s.a,b.a)&&J.aq(s.b,b.b)&&J.aq(s.c,b.c)},
gm(a){var s=this
return A.ib(s.$s,s.a,s.b,s.c)}}
A.dF.prototype={
j(a){return"RegExp/"+this.a+"/"+this.b.flags}}
A.aD.prototype={
gn(a){return B.C},
$im:1,
$if3:1}
A.b5.prototype={}
A.c1.prototype={
gn(a){return B.D},
$im:1,
$if4:1}
A.aE.prototype={
gB(a){return a.length},
$iE:1}
A.b3.prototype={$ii:1,$ie:1,$ik:1}
A.b4.prototype={$ii:1,$ie:1,$ik:1}
A.c2.prototype={
gn(a){return B.E},
$im:1,
$id3:1}
A.c3.prototype={
gn(a){return B.F},
$im:1,
$id4:1}
A.c4.prototype={
gn(a){return B.G},
$im:1,
$idb:1}
A.c5.prototype={
gn(a){return B.H},
$im:1,
$idc:1}
A.c6.prototype={
gn(a){return B.I},
$im:1,
$idd:1}
A.c7.prototype={
gn(a){return B.K},
$im:1,
$ie6:1}
A.c8.prototype={
gn(a){return B.L},
$im:1,
$ie7:1}
A.b6.prototype={
gn(a){return B.M},
gB(a){return a.length},
$im:1,
$ie8:1}
A.c9.prototype={
gn(a){return B.N},
gB(a){return a.length},
$im:1,
$ie9:1}
A.bj.prototype={}
A.bk.prototype={}
A.bl.prototype={}
A.bm.prototype={}
A.J.prototype={
i(a){return A.bw(v.typeUniverse,this,a)},
u(a){return A.h0(v.typeUniverse,this,a)}}
A.cx.prototype={}
A.ex.prototype={
j(a){return A.F(this.a,null)}}
A.cw.prototype={
j(a){return this.a}}
A.bs.prototype={$iU:1}
A.eb.prototype={
$1(a){var s=this.a,r=s.a
s.a=null
r.$0()},
$S:8}
A.ea.prototype={
$1(a){var s,r
this.a.a=a
s=this.b
r=this.c
s.firstChild?s.removeChild(r):s.appendChild(r)},
$S:15}
A.ec.prototype={
$0(){this.a.$0()},
$S:2}
A.ed.prototype={
$0(){this.a.$0()},
$S:2}
A.br.prototype={
aX(a,b){if(self.setTimeout!=null)self.setTimeout(A.cF(new A.ew(this,b),0),a)
else throw A.f(A.bd("`setTimeout()` not found."))},
aY(a,b){if(self.setTimeout!=null)self.setInterval(A.cF(new A.ev(this,a,Date.now(),b),0),a)
else throw A.f(A.bd("Periodic timer."))},
$ie3:1}
A.ew.prototype={
$0(){this.a.c=1
this.b.$0()},
$S:1}
A.ev.prototype={
$0(){var s,r=this,q=r.a,p=q.c+1,o=r.b
if(o>0){s=Date.now()-r.c
if(s>(p+1)*o)p=B.b.aV(s,o)}q.c=p
r.d.$1(q)},
$S:2}
A.P.prototype={
j(a){return A.o(this.a)},
$ip:1,
gN(){return this.b}}
A.d6.prototype={
$0(){var s,r,q,p,o,n,m=this,l=m.a
if(l==null){m.c.a(null)
m.b.ai(null)}else{s=null
try{s=l.$0()}catch(p){r=A.a9(p)
q=A.an(p)
l=r
o=q
n=A.ja(l,o)
l=new A.P(l,o)
m.b.a1(l)
return}m.b.ai(s)}},
$S:1}
A.cy.prototype={
bv(a){if((this.c&15)!==6)return!0
return this.b.b.ab(this.d,a.a)},
bp(a){var s,r=this.e,q=null,p=a.a,o=this.b.b
if(t.C.b(r))q=o.bB(r,p,a.b)
else q=o.ab(r,p)
try{p=q
return p}catch(s){if(t.b7.b(A.a9(s))){if((this.c&1)!==0)throw A.f(A.aQ("The error handler of Future.then must return a value of the returned future's type","onError"))
throw A.f(A.aQ("The error handler of Future.catchError must return a value of the future's type","onError"))}else throw s}}}
A.K.prototype={
bH(a,b,c){var s,r=$.w
if(r===B.c){if(!t.C.b(b)&&!t.v.b(b))throw A.f(A.fw(b,"onError",u.c))}else b=A.jt(b,r)
s=new A.K(r,c.i("K<0>"))
this.ag(new A.cy(s,3,a,b,this.$ti.i("@<1>").u(c).i("cy<1,2>")))
return s},
bd(a){this.a=this.a&1|16
this.c=a},
R(a){this.a=a.a&30|this.a&1
this.c=a.c},
ag(a){var s=this,r=s.a
if(r<=3){a.a=s.c
s.c=a}else{if((r&4)!==0){r=s.c
if((r.a&24)===0){r.ag(a)
return}s.R(r)}A.eP(null,null,s.b,new A.ef(s,a))}},
au(a){var s,r,q,p,o,n=this,m={}
m.a=a
if(a==null)return
s=n.a
if(s<=3){r=n.c
n.c=a
if(r!=null){q=a.a
for(p=a;q!=null;p=q,q=o)o=q.a
p.a=r}}else{if((s&4)!==0){s=n.c
if((s.a&24)===0){s.au(a)
return}n.R(s)}m.a=n.U(a)
A.eP(null,null,n.b,new A.ei(m,n))}},
T(){var s=this.c
this.c=null
return this.U(s)},
U(a){var s,r,q
for(s=a,r=null;s!=null;r=s,s=q){q=s.a
s.a=r}return r},
ai(a){var s,r=this
if(r.$ti.i("aW<1>").b(a))A.fe(a,r,!0)
else{s=r.T()
r.a=8
r.c=a
A.aJ(r,s)}},
b2(a){var s,r,q=this
if((a.a&16)!==0){s=q.b===a.b
s=!(s||s)}else s=!1
if(s)return
r=q.T()
q.R(a)
A.aJ(q,r)},
a1(a){var s=this.T()
this.bd(a)
A.aJ(this,s)},
b1(a){this.a^=2
A.eP(null,null,this.b,new A.eg(this,a))},
$iaW:1}
A.ef.prototype={
$0(){A.aJ(this.a,this.b)},
$S:1}
A.ei.prototype={
$0(){A.aJ(this.b,this.a.a)},
$S:1}
A.eh.prototype={
$0(){A.fe(this.a.a,this.b,!0)},
$S:1}
A.eg.prototype={
$0(){this.a.a1(this.b)},
$S:1}
A.el.prototype={
$0(){var s,r,q,p,o,n,m,l,k=this,j=null
try{q=k.a.a
j=q.b.b.bz(q.d)}catch(p){s=A.a9(p)
r=A.an(p)
if(k.c&&k.b.a.c.a===s){q=k.a
q.c=k.b.a.c}else{q=s
o=r
if(o==null)o=A.f2(q)
n=k.a
n.c=new A.P(q,o)
q=n}q.b=!0
return}if(j instanceof A.K&&(j.a&24)!==0){if((j.a&16)!==0){q=k.a
q.c=j.c
q.b=!0}return}if(j instanceof A.K){m=k.b.a
l=new A.K(m.b,m.$ti)
j.bH(new A.em(l,m),new A.en(l),t.b9)
q=k.a
q.c=l
q.b=!1}},
$S:1}
A.em.prototype={
$1(a){this.a.b2(this.b)},
$S:8}
A.en.prototype={
$2(a,b){this.a.a1(new A.P(a,b))},
$S:16}
A.ek.prototype={
$0(){var s,r,q,p,o,n
try{q=this.a
p=q.a
q.c=p.b.b.ab(p.d,this.b)}catch(o){s=A.a9(o)
r=A.an(o)
q=s
p=r
if(p==null)p=A.f2(q)
n=this.a
n.c=new A.P(q,p)
n.b=!0}},
$S:1}
A.ej.prototype={
$0(){var s,r,q,p,o,n,m,l=this
try{s=l.a.a.c
p=l.b
if(p.a.bv(s)&&p.a.e!=null){p.c=p.a.bp(s)
p.b=!1}}catch(o){r=A.a9(o)
q=A.an(o)
p=l.a.a.c
if(p.a===r){n=l.b
n.c=p
p=n}else{p=r
n=q
if(n==null)n=A.f2(p)
m=l.b
m.c=new A.P(p,n)
p=m}p.b=!0}},
$S:1}
A.cv.prototype={}
A.eA.prototype={}
A.es.prototype={
bD(a){var s,r,q
try{if(B.c===$.w){a.$0()
return}A.hh(null,null,this,a)}catch(q){s=A.a9(q)
r=A.an(q)
A.eN(s,r)}},
bF(a,b){var s,r,q
try{if(B.c===$.w){a.$1(b)
return}A.hi(null,null,this,a,b)}catch(q){s=A.a9(q)
r=A.an(q)
A.eN(s,r)}},
bG(a,b){return this.bF(a,b,t.z)},
aB(a){return new A.et(this,a)},
bk(a,b){return new A.eu(this,a,b)},
bA(a){if($.w===B.c)return a.$0()
return A.hh(null,null,this,a)},
bz(a){return this.bA(a,t.z)},
bE(a,b){if($.w===B.c)return a.$1(b)
return A.hi(null,null,this,a,b)},
ab(a,b){var s=t.z
return this.bE(a,b,s,s)},
bC(a,b,c){if($.w===B.c)return a.$2(b,c)
return A.ju(null,null,this,a,b,c)},
bB(a,b,c){var s=t.z
return this.bC(a,b,c,s,s,s)},
bx(a){return a},
bw(a){var s=t.z
return this.bx(a,s,s,s)}}
A.et.prototype={
$0(){return this.a.bD(this.b)},
$S:1}
A.eu.prototype={
$1(a){return this.a.bG(this.b,a)},
$S(){return this.c.i("~(0)")}}
A.eO.prototype={
$0(){A.i_(this.a,this.b)},
$S:1}
A.be.prototype={
gaa(){return new A.bf(this,this.$ti.i("bf<1>"))},
a8(a){var s,r
if(typeof a=="string"&&a!=="__proto__"){s=this.b
return s==null?!1:s[a]!=null}else if(typeof a=="number"&&(a&1073741823)===a){r=this.c
return r==null?!1:r[a]!=null}else return this.b6(a)},
b6(a){var s=this.d
if(s==null)return!1
return this.H(this.an(s,a),a)>=0},
G(a,b){var s,r,q
if(typeof b=="string"&&b!=="__proto__"){s=this.b
r=s==null?null:A.fQ(s,b)
return r}else if(typeof b=="number"&&(b&1073741823)===b){q=this.c
r=q==null?null:A.fQ(q,b)
return r}else return this.ba(b)},
ba(a){var s,r,q=this.d
if(q==null)return null
s=this.an(q,a)
r=this.H(s,a)
return r<0?null:s[r+1]},
t(a,b,c){var s,r,q,p=this,o=p.d
if(o==null)o=p.d=A.iu()
s=A.f_(b)&1073741823
r=o[s]
if(r==null){A.fR(o,s,[b,c]);++p.a
p.e=null}else{q=p.H(r,b)
if(q>=0)r[q+1]=c
else{r.push(b,c);++p.a
p.e=null}}},
a9(a,b){var s,r,q,p,o,n=this,m=n.aj()
for(s=m.length,r=n.$ti.y[1],q=0;q<s;++q){p=m[q]
o=n.G(0,p)
b.$2(p,o==null?r.a(o):o)
if(m!==n.e)throw A.f(A.Q(n))}},
aj(){var s,r,q,p,o,n,m,l,k,j,i=this,h=i.e
if(h!=null)return h
h=A.fG(i.a,null,!1,t.z)
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
an(a,b){return a[A.f_(b)&1073741823]}}
A.bg.prototype={
H(a,b){var s,r,q
if(a==null)return-1
s=a.length
for(r=0;r<s;r+=2){q=a[r]
if(q==null?b==null:q===b)return r}return-1}}
A.bf.prototype={
gq(a){var s=this.a
return new A.cz(s,s.aj(),this.$ti.i("cz<1>"))}}
A.cz.prototype={
gl(){var s=this.d
return s==null?this.$ti.c.a(s):s},
k(){var s=this,r=s.b,q=s.c,p=s.a
if(r!==p.e)throw A.f(A.Q(p))
else if(q>=r.length){s.d=null
return!1}else{s.d=r[q]
s.c=q+1
return!0}}}
A.bi.prototype={
gq(a){var s=this,r=new A.aK(s,s.r,s.$ti.i("aK<1>"))
r.c=s.e
return r},
bl(a,b){var s,r
if(b!=="__proto__"){s=this.b
if(s==null)return!1
return s[b]!=null}else{r=this.b5(b)
return r}},
b5(a){var s=this.d
if(s==null)return!1
return this.H(s[B.d.gm(a)&1073741823],a)>=0},
D(a,b){var s,r,q=this
if(typeof b=="string"&&b!=="__proto__"){s=q.b
return q.af(s==null?q.b=A.ff():s,b)}else if(typeof b=="number"&&(b&1073741823)===b){r=q.c
return q.af(r==null?q.c=A.ff():r,b)}else return q.b_(b)},
b_(a){var s,r,q=this,p=q.d
if(p==null)p=q.d=A.ff()
s=J.N(a)&1073741823
r=p[s]
if(r==null)p[s]=[q.a4(a)]
else{if(q.H(r,a)>=0)return!1
r.push(q.a4(a))}return!0},
af(a,b){if(a[b]!=null)return!1
a[b]=this.a4(b)
return!0},
ap(){this.r=this.r+1&1073741823},
a4(a){var s,r=this,q=new A.ep(a)
if(r.e==null)r.e=r.f=q
else{s=r.f
s.toString
q.c=s
r.f=s.b=q}++r.a
r.ap()
return q},
H(a,b){var s,r
if(a==null)return-1
s=a.length
for(r=0;r<s;++r)if(J.aq(a[r].a,b))return r
return-1}}
A.ep.prototype={}
A.aK.prototype={
gl(){var s=this.d
return s==null?this.$ti.c.a(s):s},
k(){var s=this,r=s.c,q=s.a
if(s.b!==q.r)throw A.f(A.Q(q))
else if(r==null){s.d=null
return!1}else{s.d=r.a
s.c=r.b
return!0}}}
A.r.prototype={
gq(a){return new A.aB(a,a.length,A.ao(a).i("aB<r.E>"))},
Y(a,b){return a[b]},
aN(a,b){return new A.W(a,b,A.ao(a).i("W<r.E>"))},
J(a,b,c){return new A.T(a,b,A.ao(a).i("@<r.E>").u(c).i("T<1,2>"))},
D(a,b){var s=a.length
this.sB(a,s+1)
a[s]=b},
j(a){return A.f7(a,"[","]")}}
A.a1.prototype={
a9(a,b){var s,r,q,p
for(s=this.gaa(),s=s.gq(s),r=A.a5(this).y[1];s.k();){q=s.gl()
p=this.G(0,q)
b.$2(q,p==null?r.a(p):p)}},
j(a){return A.fH(this)},
$ia0:1}
A.dJ.prototype={
$2(a,b){var s,r=this.a
if(!r.a)this.b.a+=", "
r.a=!1
r=this.b
s=A.o(a)
r.a=(r.a+=s)+": "
s=A.o(b)
r.a+=s},
$S:17}
A.aG.prototype={
J(a,b,c){return new A.aa(this,b,this.$ti.i("@<1>").u(c).i("aa<1,2>"))},
j(a){return A.f7(this,"{","}")},
$ii:1,
$ie:1}
A.bp.prototype={}
A.aw.prototype={
F(a,b){if(b==null)return!1
return b instanceof A.aw&&this.a===b.a},
gm(a){return B.b.gm(this.a)},
j(a){var s,r,q,p=this.a,o=p%36e8,n=B.b.av(o,6e7)
o%=6e7
s=n<10?"0":""
r=B.b.av(o,1e6)
q=r<10?"0":""
return""+(p/36e8|0)+":"+s+n+":"+q+r+"."+B.d.aJ(B.b.j(o%1e6),6,"0")}}
A.p.prototype={
gN(){return A.id(this)}}
A.bE.prototype={
j(a){var s=this.a
if(s!=null)return"Assertion failed: "+A.d1(s)
return"Assertion failed"}}
A.U.prototype={}
A.O.prototype={
gal(){return"Invalid argument"+(!this.a?"(s)":"")},
gak(){return""},
j(a){var s=this,r=s.c,q=r==null?"":" ("+r+")",p=s.d,o=p==null?"":": "+p,n=s.gal()+q+o
if(!s.a)return n
return n+s.gak()+": "+A.d1(s.gaG())},
gaG(){return this.b}}
A.ch.prototype={
gaG(){return this.b},
gal(){return"RangeError"},
gak(){var s,r=this.e,q=this.f
if(r==null)s=q!=null?": Not less than or equal to "+A.o(q):""
else if(q==null)s=": Not greater than or equal to "+A.o(r)
else if(q>r)s=": Not in inclusive range "+A.o(r)+".."+A.o(q)
else s=q<r?": Valid value range is empty":": Only valid value is "+A.o(r)
return s}}
A.bc.prototype={
j(a){return"Unsupported operation: "+this.a}}
A.cs.prototype={
j(a){return"UnimplementedError: "+this.a}}
A.co.prototype={
j(a){return"Bad state: "+this.a}}
A.bI.prototype={
j(a){var s=this.a
if(s==null)return"Concurrent modification during iteration."
return"Concurrent modification during iteration: "+A.d1(s)+"."}}
A.cb.prototype={
j(a){return"Out of Memory"},
gN(){return null},
$ip:1}
A.ba.prototype={
j(a){return"Stack Overflow"},
gN(){return null},
$ip:1}
A.ee.prototype={
j(a){return"Exception: "+this.a}}
A.d5.prototype={
j(a){var s=this.a,r=""!==s?"FormatException: "+s:"FormatException",q=this.b
if(q.length>78)q=B.d.aS(q,0,75)+"..."
return r+"\n"+q}}
A.e.prototype={
J(a,b,c){return A.ia(this,b,A.a5(this).i("e.E"),c)},
j(a){return A.i0(this,"(",")")}}
A.ag.prototype={
j(a){return"MapEntry("+A.o(this.a)+": "+A.o(this.b)+")"}}
A.B.prototype={
gm(a){return A.j.prototype.gm.call(this,0)},
j(a){return"null"}}
A.j.prototype={$ij:1,
F(a,b){return this===b},
gm(a){return A.cf(this)},
j(a){return"Instance of '"+A.cg(this)+"'"},
gn(a){return A.hr(this)},
toString(){return this.j(this)}}
A.cB.prototype={
j(a){return""},
$iaI:1}
A.dZ.prototype={
gbn(){var s,r=this.b
if(r==null)r=$.dQ.$0()
s=r-this.a
if($.fu()===1e6)return s
return s*1000}}
A.cq.prototype={
j(a){var s=this.a
return s.charCodeAt(0)==0?s:s}}
A.eX.prototype={
$1(a){var s,r,q,p
if(A.hf(a))return a
s=this.a
if(s.a8(a))return s.G(0,a)
if(a instanceof A.a1){r={}
s.t(0,a,r)
for(s=a.gaa(),s=s.gq(s);s.k();){q=s.gl()
r[q]=this.$1(a.G(0,q))}return r}else if(t.e.b(a)){p=[]
s.t(0,a,p)
B.h.aA(p,J.cJ(a,this,t.z))
return p}else return a},
$S:18}
A.as.prototype={}
A.l.prototype={}
A.aS.prototype={}
A.aV.prototype={}
A.bZ.prototype={}
A.aU.prototype={}
A.ci.prototype={}
A.ab.prototype={}
A.A.prototype={}
A.ay.prototype={}
A.x.prototype={}
A.R.prototype={}
A.aH.prototype={}
A.cc.prototype={}
A.bM.prototype={}
A.bN.prototype={}
A.bO.prototype={}
A.au.prototype={}
A.bQ.prototype={}
A.bC.prototype={}
A.bP.prototype={}
A.bL.prototype={}
A.c_.prototype={}
A.ca.prototype={}
A.ck.prototype={}
A.ce.prototype={}
A.cV.prototype={}
A.bo.prototype={
X(){var s,r,q,p,o,n
for(r=this.a,q=A.fS(r,r.r,r.$ti.c),p=q.$ti.c;q.k();){o=q.d
s=o==null?p.a(o):o
try{s.$0()}catch(n){}}if(r.a>0){r.b=r.c=r.d=r.e=r.f=null
r.a=0
r.ap()}}}
A.bh.prototype={}
A.eF.prototype={
$0(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d=this,c=d.a,b=c.a.$0(),a=A.aA(t.N),a0=A.b([],t.h)
for(s=b.length,r=t.M,c=c.b,q=d.c,p=d.b,o=0;o<b.length;b.length===s||(0,A.M)(b),++o){n=b[o]
m=p.$1(n)
a.D(0,m)
if(q.a8(m)){l=q.G(0,m)
l.toString
a0.push(l)}else{k=new A.bo(A.aA(r))
j=new A.bh(A.cE(c.$1(n),k),k)
q.t(0,m,j)
a0.push(j)}}c=A.a5(q).i("af<1>")
s=c.i("W<e.E>")
i=A.aC(new A.W(new A.af(q,c),new A.eG(a),s),s.i("e.E"))
for(c=i.length,s=d.d,o=0;o<i.length;i.length===c||(0,A.M)(i),++o){j=q.by(0,i[o])
j.c.X()
for(r=j.b,p=r.length,h=0;h<r.length;r.length===p||(0,A.M)(r),++h){g=r[h]
if(J.aq(g.parentNode,s))s.removeChild(g)}}for(f=0;f<a0.length;++f)for(c=a0[f].b,r=c.length,o=0;o<c.length;c.length===r||(0,A.M)(c),++o){g=c[o]
e=s.childNodes.item(f)
if(e!==g)s.insertBefore(g,e)}},
$S:1}
A.eG.prototype={
$1(a){return!this.a.bl(0,a)},
$S:19}
A.eE.prototype={
$0(){this.a.$0()},
$S:2}
A.eD.prototype={
$0(){var s,r
this.a.$0()
for(s=this.b,r=new A.bY(s,s.r,s.e);r.k();)r.d.c.X()
if(s.a>0){s.b=s.c=s.d=s.e=s.f=null
s.a=0
s.a_()}},
$S:1}
A.eJ.prototype={
$0(){var s,r,q,p,o=this,n=o.a
n.X()
s=o.b.$0()
r=o.c
q=A.cE(r==null?t.c.a(s):r.$1(s),n)
n=o.d
n.textContent=""
for(r=q.length,p=0;p<q.length;q.length===r||(0,A.M)(q),++p)n.appendChild(q[p])},
$S:1}
A.eI.prototype={
$0(){this.a.$0()},
$S:2}
A.eH.prototype={
$0(){this.a.$0()
this.b.X()},
$S:1}
A.eB.prototype={
$1(a){this.b.$1(A.jD(this.a,a))},
$S:20}
A.cK.prototype={
A(){var s=this,r=null,q="px-2 py-0.5 rounded bg-[#1E1E24] hover:bg-[#27272A] text-xs font-mono text-zinc-300 cursor-pointer",p="flex items-center gap-2",o="text-zinc-400",n=t.N,m=t.t
return A.cl(A.q(["id","benchmark"],n,n),A.b([A.d(A.b([A.a(u.a,"Real-Time Telemetry & Comparative Benchmarks"),A.d7(u.d,"Fine-Grained Signals vs VDOM Diffing"),A.ah("text-zinc-400 text-base leading-relaxed","Unlike React or Flutter which recreate virtual element trees on every state change, Bloom binds signals directly to individual DOM text nodes and attributes with zero reconciliation overhead.")],m),"text-center max-w-3xl mx-auto mb-12"),A.d(A.b([A.d(A.b([A.d(A.b([A.D(A.b([new A.A(new A.cM(s)),new A.A(new A.cN(s))],m),"px-4 py-2.5 rounded-lg font-medium text-xs flex items-center gap-2 cursor-pointer transition-all bg-indigo-600 hover:bg-indigo-500 text-white shadow-md shadow-indigo-600/20 active:scale-95",new A.cO(s),r),A.d(A.b([A.a("text-xs text-zinc-400 font-mono","Nodes:"),new A.A(new A.cP(s)),A.D(B.a,q,new A.cQ(s),"-"),A.D(B.a,q,new A.cR(s),"+")],m),"flex items-center gap-3 bg-[#14141A] px-4 py-2 rounded-lg border border-[#27272A]")],m),"flex items-center gap-4 flex-wrap"),A.d(A.b([A.d(A.b([A.a("w-2 h-2 rounded-full bg-emerald-400 animate-pulse",r),A.a(o,"FPS:"),new A.A(new A.cS(s))],m),p),A.d(A.b([A.a("w-2 h-2 rounded-full bg-indigo-400",r),A.a(o,"Patch Latency:"),new A.A(new A.cT(s))],m),p)],m),"flex items-center gap-6 font-mono text-xs")],m),"flex flex-col md:flex-row md:items-center justify-between gap-6 pb-6 border-b border-[#1E1E24]"),A.d(A.b([A.d(A.b([new A.A(new A.cU(s))],m),"grid grid-cols-3 sm:grid-cols-6 md:grid-cols-12 gap-2.5")],m),"pt-6")],m),"rounded-2xl bg-[#101014] border border-[#1E1E24] p-6 sm:p-8 shadow-2xl overflow-hidden mb-12"),A.d(A.b([A.d(A.b([A.d(A.b([A.f5("text-lg font-bold text-white","Benchmark Matrix: Web Frameworks Comparison"),A.ah("text-xs text-zinc-400 mt-0.5","Independent cold-start SSR latency and production JS gzip footprint benchmarks.")],m),r),A.a("text-xs font-mono px-3 py-1 rounded-full bg-[#14141A] text-indigo-400 border border-[#27272A]","Chart.js Native Binding")],m),"flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6"),A.d(A.b([new A.x('<canvas id="perf-chart" class="w-full h-full"></canvas>')],m),"h-72 w-full relative")],m),"rounded-2xl bg-[#101014] border border-[#1E1E24] p-6 sm:p-8 shadow-2xl")],m),"py-20 px-6 max-w-7xl mx-auto")}}
A.cO.prototype={
$1(a){var s=this.a.a.f
s.sh(!s.gh())
return null},
$S:0}
A.cM.prototype={
$0(){return this.a.a.f.gh()?new A.x('<svg class="w-3.5 h-3.5 animate-spin" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v8H4z"></path></svg>'):new A.x('<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"></path><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>')},
$S:9}
A.cN.prototype={
$0(){return A.a(null,this.a.a.f.gh()?"Pause Stress Ticker":"Run Live Stress Ticker")},
$S:4}
A.cP.prototype={
$0(){return A.a("text-xs font-mono font-bold text-white",""+this.a.a.b.gh())},
$S:4}
A.cQ.prototype={
$1(a){var s=this.a.a
return s.aM(B.b.aC(s.b.gh()-12,12,120))},
$S:0}
A.cR.prototype={
$1(a){var s=this.a.a
return s.aM(B.b.aC(s.b.gh()+12,12,120))},
$S:0}
A.cS.prototype={
$0(){return A.a("text-emerald-400 font-bold",""+this.a.a.c.gh())},
$S:4}
A.cT.prototype={
$0(){return A.a("text-indigo-400 font-bold",A.o(this.a.a.d.gh())+" ms")},
$S:4}
A.cU.prototype={
$0(){var s=J.cJ(this.a.a.e.gh(),new A.cL(),t._)
s=A.aC(s,s.$ti.i("I.E"))
return new A.ab(s)},
$S:21}
A.cL.prototype={
$1(a){return A.d(A.b([A.a("text-[10px] font-mono text-zinc-500","#"+a),A.a("text-sm font-mono font-bold text-indigo-400 mt-1",""+B.b.ac(a*137,999))],t.t),"p-3 rounded-lg bg-[#14141A] border border-[#27272A] flex flex-col items-center justify-center transition-colors shadow-sm")},
$S:22}
A.cW.prototype={
A(){var s=this,r="flex items-center gap-2",q=null,p=t.N,o=t.t
return A.cl(A.q(["id","code"],p,p),A.b([A.d(A.b([A.a(u.a,"Developer Ergonomics"),A.d7(u.d,"Clean, Declarative Pure Dart"),A.ah("text-zinc-400 text-base leading-relaxed","No HTML templates, no JSX, and zero dynamic code generation at runtime. Every component is a strongly-typed, tree-shakeable AST descriptor tree.")],o),"text-center max-w-3xl mx-auto mb-12"),A.d(A.b([A.d(A.b([A.d(A.b([A.a("w-3 h-3 rounded-full bg-[#EF4444]/80 border border-[#DC2626]",q),A.a("w-3 h-3 rounded-full bg-[#F59E0B]/80 border border-[#D97706]",q),A.a("w-3 h-3 rounded-full bg-[#10B981]/80 border border-[#059669]",q)],o),r),A.d(A.b([s.a6("main.dart","UI Component"),s.a6("ssr_router.dart","Server SSR"),s.a6("bloom.yaml","NPM Toolchain")],o),r),A.D(A.b([new A.x('<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>'),A.a(q,"Copy")],o),"text-xs font-mono px-2.5 py-1 rounded bg-[#14141A] hover:bg-[#1E1E24] text-zinc-400 hover:text-white border border-[#27272A] flex items-center gap-1.5 transition-colors cursor-pointer",new A.cZ(s),q)],o),"px-4 py-3 bg-[#101014] border-b border-[#1E1E24] flex items-center justify-between"),A.d(A.b([new A.A(new A.d_(s))],o),"p-6 font-mono text-xs sm:text-sm leading-relaxed overflow-x-auto text-zinc-300 custom-scrollbar bg-[#09090B]")],o),"max-w-4xl mx-auto rounded-2xl bg-[#09090B] border border-[#1E1E24] shadow-2xl overflow-hidden")],o),"py-20 px-6 max-w-7xl mx-auto")},
a6(a,b){return new A.A(new A.cY(this,a,b))},
bc(a){var s="flex",r="flex-1 pl-4",q="text-zinc-500 italic",p="text-[#818CF8] font-bold",o="import",n=null,m=" 'package:bloom_js_native/bloom_js_native.dart';\n",l="text-[#C084FC] font-bold",k=" main() {\n",j="      children: [\n",i="      ],\n",h="text-[#38BDF8]",g=t.t
switch(a){case"ssr_router.dart":return A.d(A.b([this.a2(18),A.dN(A.b([A.a(q,"// apps/server/bin/server.dart\n"),A.a(p,o),A.a(n," 'package:bloom_framework/bloom.dart';\n"),A.a(p,o),A.a(n,m),A.a(p,o),A.a(n," 'package:bloom_seo/bloom_seo.dart';\n\n"),A.a(l,"void"),A.a(n,k),A.a(n,"  final router = BloomApiRouter();\n\n"),A.a(q,"  // Unified Sub-Millisecond SSR Route (<1ms response)\n"),A.a(n,"  router.ssr(\n"),A.a(n,"    '/',\n"),A.a(n,"    (req) => Div(\n"),A.a(n,"      className: 'min-h-screen bg-black text-white p-12',\n"),A.a(n,j),A.a(n,"        H1(className: 'text-4xl font-bold', text: 'Bloom SSR'),\n"),A.a(n,"        P(text: 'Zero JavaScript loaded on initial paint.'),\n"),A.a(n,i),A.a(n,"    ),\n"),A.a(n,"    head: (req) => HeadManager(initialTitle: 'Bloom Fast SSR'),\n"),A.a(n,"  );\n\n"),A.a(n,"  router.listen(port: 8080);\n"),A.a(n,"}\n")],g),r)],g),s)
case"bloom.yaml":return A.d(A.b([this.a2(15),A.dN(A.b([A.a(q,"# bloom.yaml \u2014 Zero Configuration Toolchain\n"),A.a(p,"name"),A.a(n,": showcase_app\n"),A.a(p,"target"),A.a(n,": web_dom\n\n"),A.a("text-[#F472B6] font-bold","npm_packages"),A.a(n,":\n"),A.a(h,"  three"),A.a(n,":\n"),A.a(n,"    npm_name: three\n"),A.a(n,"    version: 0.160.0\n"),A.a(n,"    vendor_file: web/vendor/three.min.js\n"),A.a(n,"    dart_binding: lib/plugins/three_js.dart\n\n"),A.a(h,"  canvas-confetti"),A.a(n,":\n"),A.a(n,"    npm_name: canvas-confetti\n"),A.a(n,"    version: 1.9.3\n"),A.a(n,"    vendor_file: web/vendor/canvas-confetti.min.js\n")],g),r)],g),s)
default:return A.d(A.b([this.a2(24),A.dN(A.b([A.a(q,"// lib/main.dart \u2014 Fine-Grained Signals UI\n"),A.a(p,o),A.a(n,m),A.a(p,o),A.a(n," 'package:bloom_js_native/browser.dart';\n\n"),A.a(l,"void"),A.a(n,k),A.a(n,"  final count = signal("),A.a("text-[#FBBF24]","0"),A.a(n,");\n"),A.a(n,"  final isEven = computed(() => count.value.isEven);\n\n"),A.a(n,"  mount(\n"),A.a(n,"    Div(\n"),A.a(n,"      className: 'p-6 bg-zinc-950 rounded-2xl border border-zinc-800 max-w-md mx-auto',\n"),A.a(n,j),A.a(n,"        Live(() => H2(\n"),A.a(n,"          className: 'text-2xl font-bold text-white',\n"),A.a(n,'          text: \'Count: ${count.value} (${isEven.value ? "Even" : "Odd"})\',\n'),A.a(n,"        )),\n"),A.a(n,"        Button(\n"),A.a(n,"          className: 'mt-4 px-4 py-2 bg-indigo-600 hover:bg-indigo-500 text-white rounded-lg',\n"),A.a(n,"          onClick: (_) => count.value++,\n"),A.a(n,"          text: 'Increment Signal',\n"),A.a(n,"        ),\n"),A.a(n,i),A.a(n,"    ),\n"),A.a(n,"    '#app',\n"),A.a(n,"  );\n"),A.a(n,"}\n")],g),r)],g),s)}},
a2(a){var s,r,q,p=J.dE(a,t.N)
for(s=0;s<a;s=r){r=s+1
p[s]=B.d.aJ(""+r,2," ")}q=t.t
return A.d(A.b([A.dN(A.b([A.a(null,B.h.bu(p,"\n"))],q),null)],q),"select-none pr-4 text-right border-r border-[#1E1E24] text-zinc-600 font-mono text-xs sm:text-sm")}}
A.cZ.prototype={
$1(a){return this.a.a.M("Snippet copied to clipboard!")},
$S:0}
A.d_.prototype={
$0(){var s=this.a
return s.bc(s.a.a.gh())},
$S:3}
A.cY.prototype={
$0(){var s=this.a,r=this.b
return A.D(B.a,"px-3 py-1.5 text-xs font-mono rounded-md transition-all cursor-pointer "+(s.a.a.gh()===r?"bg-[#1E1E24] text-white font-semibold shadow-sm border border-[#27272A]":"text-zinc-500 hover:text-zinc-300"),new A.cX(s,r),this.c)},
$S:10}
A.cX.prototype={
$1(a){this.a.a.a.sh(this.b)
return null},
$S:0}
A.d2.prototype={
P(a,b,c,d){var s=t.t
return A.d(A.b([A.d(A.b([A.d(A.b([A.d(A.b([new A.x('<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">'+b+"</svg>")],s),"w-12 h-12 rounded-xl bg-[#14141A] border border-[#27272A] flex items-center justify-center text-indigo-400 group-hover:text-white group-hover:bg-indigo-600 transition-colors"),A.a("text-xs font-mono px-2.5 py-1 rounded-full bg-[#14141A] text-zinc-400 border border-[#27272A]",c)],s),"flex items-center justify-between mb-6"),A.f5("text-xl font-bold text-white mb-3 tracking-tight",d),A.ah("text-zinc-400 text-sm leading-relaxed",a)],s),null)],s),"group p-8 rounded-2xl bg-[#101014] border border-[#1E1E24] hover:border-indigo-500/40 transition-all duration-300 relative overflow-hidden flex flex-col justify-between shadow-lg")}}
A.d8.prototype={
A(){var s=this,r=null,q=t.t,p=A.d(A.b([new A.x('<canvas id="three-hero-canvas" class="w-full h-full max-w-5xl max-h-[640px]"></canvas>')],q),"absolute inset-0 pointer-events-none flex items-center justify-center opacity-70 z-0"),o=A.d(A.b([A.a("w-2 h-2 rounded-full bg-indigo-500 animate-pulse",r),A.a(r,"Bloom 1.0 \u2014 The Fine-Grained Web Architecture for Dart")],q),"inline-flex items-center gap-2.5 px-4 py-1.5 rounded-full bg-[#14141A]/90 border border-indigo-500/30 text-xs font-medium text-zinc-300 mb-8 shadow-lg shadow-indigo-500/10 backdrop-blur-sm"),n=A.b([A.a(r,"Pure Dart on the DOM.\n"),A.a("bg-gradient-to-r from-indigo-400 via-violet-300 to-cyan-300 bg-clip-text text-transparent drop-shadow-sm","0kB Flutter Runtime.")],q)
return A.cl(r,A.b([p,A.d(A.b([o,new A.bM("h1",r,"text-5xl sm:text-6xl md:text-7xl font-extrabold tracking-tight text-white mb-6 leading-[1.1]",r,r,A.a6(r,r,r,r,r,r,r),n),A.ah("max-w-2xl text-lg sm:text-xl text-zinc-400 mb-10 leading-relaxed font-normal","Dart owns reactivity, compilation, and tooling. The browser owns rendering. Surgical ESM imports via Bun with sub-millisecond SSR execution."),A.d(A.b([A.D(A.b([A.a("text-xs font-mono text-zinc-500 select-none","$"),A.a("text-sm font-mono text-zinc-200 font-medium","bloom create my_app --target=web_dom"),new A.A(new A.d9(s))],q),"group px-5 py-3.5 rounded-xl bg-[#14141A] hover:bg-[#1E1E24] border border-[#27272A] hover:border-indigo-500/50 flex items-center gap-3 transition-all cursor-pointer shadow-xl shadow-black/60 active:scale-95",new A.da(s),r),A.ar(A.b([new A.x('<svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24"><path fill-rule="evenodd" clip-rule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.53 1.032 1.53 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z"/></svg>'),A.a(r,"Star on GitHub")],q),"px-6 py-3.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-semibold flex items-center gap-2 transition-all shadow-lg shadow-indigo-600/30 cursor-pointer active:scale-95","https://github.com/Chidi09/Bloom",r)],q),"flex flex-col sm:flex-row items-center gap-4 mb-16 w-full justify-center"),A.d(A.b([s.S("< 1ms","SSR HTML Baseline","text-indigo-400"),s.S("82 kB","Production Bundle","text-violet-400"),s.S("0 kB","Flutter Engine","text-cyan-400"),s.S("100%","Fine-Grained Signals","text-emerald-400")],q),"grid grid-cols-2 sm:grid-cols-4 gap-4 w-full pt-8 border-t border-[#1E1E24]")],q),"relative max-w-5xl mx-auto text-center flex flex-col items-center z-10")],q),"relative pt-24 pb-20 px-6 overflow-hidden")},
S(a,b,c){return A.d(A.b([A.a("text-2xl sm:text-3xl font-extrabold font-mono mb-1 "+c+" tracking-tight",a),A.a("text-xs text-zinc-400 font-medium",b)],t.t),"p-4 rounded-xl bg-[#101014]/90 border border-[#1E1E24] text-center flex flex-col items-center justify-center backdrop-blur-sm shadow-md")}}
A.da.prototype={
$1(a){return this.a.a.aK()},
$S:0}
A.d9.prototype={
$0(){return this.a.a.w.gh()?new A.x('<svg class="w-4 h-4 text-emerald-400 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7"/></svg>'):new A.x('<svg class="w-4 h-4 text-zinc-400 group-hover:text-white ml-2 transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>')},
$S:9}
A.de.prototype={
gbt(a){var s=this.f
return s===$?this.f=A.fo(new A.dC(this),t.y):s},
gaH(){var s=this.x
return s===$?this.x=A.fo(new A.dB(this),t.y):s},
gaI(){var s=this.y
return s===$?this.y=A.fo(new A.dD(this),t.y):s},
A(){var s=this,r=t.N,q=t.t
return A.cl(A.q(["id","sandbox"],r,r),A.b([A.d(A.b([A.a(u.a,"Interactive Component Lab"),A.d7(u.d,"Test-Drive Bloom Reactivity Live"),A.ah("text-zinc-400 text-base leading-relaxed","Every interaction below runs 100% fine-grained Bloom signals compiled from pure Dart. No virtual DOM diffing, no state loss.")],q),"text-center max-w-3xl mx-auto mb-12"),A.d(A.b([A.d(A.b([s.V(0,"Keyed Reactive List"),s.V(1,"Signal Counter"),s.V(2,"Live Form Validation"),s.V(3,"Confetti Particle Cannon")],q),"flex items-center gap-2 pb-6 border-b border-[#1E1E24] overflow-x-auto custom-scrollbar"),A.d(A.b([new A.A(new A.dA(s))],q),"pt-6")],q),"max-w-4xl mx-auto rounded-2xl bg-[#101014] border border-[#1E1E24] p-6 sm:p-8 shadow-2xl")],q),"py-20 px-6 max-w-7xl mx-auto")},
V(a,b){return new A.A(new A.dq(this,a,b))},
bi(){var s=this,r=t.t
return A.d(A.b([A.d(A.b([A.f6("flex-1 bg-[#14141A] border border-[#27272A] rounded-xl px-4 py-2.5 text-sm text-white focus:outline-none focus:border-indigo-500 transition-colors",new A.dv(s),"Add new task...",null,s.d.gh()),A.D(B.a,"px-5 py-2.5 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl text-xs font-semibold cursor-pointer transition-colors shadow-md",new A.dw(s),"Add Task")],r),"flex gap-3"),A.d(A.b([new A.ay(new A.dx(s),new A.dy(s),new A.dz(),t.a)],r),"space-y-2 pt-2")],r),"space-y-4 max-w-xl mx-auto")},
b7(){var s,r=this,q=A.a("text-xs font-mono text-zinc-500 uppercase tracking-widest","Signal Value"),p=A.f5("text-5xl font-extrabold font-mono text-white mt-2 mb-1",""+r.e.gh()),o=r.gbt(0),n=o.gh()?"bg-emerald-500/10 text-emerald-400 border border-emerald-500/20":"bg-violet-500/10 text-violet-400 border border-violet-500/20"
o=o.gh()?"Even Number":"Odd Number"
s=t.t
return A.d(A.b([A.d(A.b([q,p,A.a("text-xs font-mono px-2.5 py-0.5 rounded-full "+n,o)],s),"p-6 rounded-2xl bg-[#14141A] border border-[#27272A]"),A.d(A.b([A.D(B.a,"px-5 py-2.5 rounded-xl bg-[#1E1E24] hover:bg-[#27272A] text-white font-mono text-sm cursor-pointer border border-[#27272A]",new A.dh(r),"- Decrement"),A.D(B.a,"px-5 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-mono text-sm cursor-pointer shadow-md shadow-indigo-600/20",new A.di(r),"+ Increment")],s),"flex justify-center gap-3")],s),"text-center py-6 max-w-sm mx-auto space-y-6")},
b9(){var s=this,r="space-y-1.5",q="text-xs font-medium text-zinc-300",p="w-full bg-[#14141A] border border-[#27272A] rounded-xl px-4 py-2.5 text-sm text-white focus:outline-none focus:border-indigo-500",o=t.t
return A.d(A.b([A.d(A.b([A.a(q,"Email Address"),A.f6(p,new A.dj(s),"alex@bloom.dev",null,null),new A.A(new A.dk(s))],o),r),A.d(A.b([A.a(q,"Password (min 8 chars)"),A.f6(p,new A.dl(s),"\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022","password",null),new A.A(new A.dm(s))],o),r),A.D(B.a,"w-full py-3 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold transition-all cursor-pointer shadow-lg shadow-indigo-600/25 mt-4",new A.dn(s),"Validate Form State")],o),"max-w-md mx-auto space-y-4 py-2")},
b4(){var s=t.t
return A.d(A.b([A.ah("text-zinc-400 text-sm leading-relaxed","Trigger multi-stage ESM particles powered by canvas-confetti native JS bindings."),A.d(A.b([A.D(B.a,"px-5 py-3 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-bold transition-all cursor-pointer shadow-lg shadow-indigo-600/30",new A.df(),"Center Explosion"),A.D(B.a,"px-5 py-3 rounded-xl bg-violet-600 hover:bg-violet-500 text-white text-xs font-bold transition-all cursor-pointer shadow-lg shadow-violet-600/30",new A.dg(),"Dual Cannons")],s),"flex justify-center gap-4 flex-wrap")],s),"text-center py-8 space-y-6 max-w-md mx-auto")}}
A.dC.prototype={
$0(){return(this.a.e.gh()&1)===0},
$S:5}
A.dB.prototype={
$0(){var s=A.ii("^[\\w-\\.]+@([\\w-]+\\.)+[\\w-]{2,4}$"),r=this.a.r.gh()
return s.b.test(r)},
$S:5}
A.dD.prototype={
$0(){return this.a.w.gh().length>=8},
$S:5}
A.dA.prototype={
$0(){var s=this.a
switch(s.b.gh()){case 1:return s.b7()
case 2:return s.b9()
case 3:return s.b4()
default:return s.bi()}},
$S:3}
A.dq.prototype={
$0(){var s=this.a,r=this.b
return A.D(B.a,"px-4 py-2 text-xs font-medium rounded-lg transition-all cursor-pointer whitespace-nowrap "+(s.b.gh()===r?"bg-indigo-600 text-white shadow-md shadow-indigo-600/20":"bg-[#14141A] hover:bg-[#1E1E24] text-zinc-400 hover:text-white border border-[#27272A]"),new A.dp(s,r),this.c)},
$S:10}
A.dp.prototype={
$1(a){var s=this.b
this.a.b.sh(s)
return s},
$S:0}
A.dv.prototype={
$1(a){var s=a.b
if(s==null)s=""
this.a.d.sh(s)
return s},
$S:0}
A.dw.prototype={
$1(a){var s,r=this.a,q=r.d,p=B.d.aL(q.gh())
if(p.length!==0){r=r.c
s=A.aC(r.gh(),t.V)
s.push(new A.a3(!1,B.b.j(Date.now()),p))
r.sh(s)
q.sh("")
A.av(0.5,0.5)}},
$S:0}
A.dx.prototype={
$0(){return this.a.c.gh()},
$S:23}
A.dy.prototype={
$1(a){var s=a.a,r=s?"bg-indigo-600 border-indigo-500 text-white":"border-zinc-700 hover:border-zinc-500",q=this.a,p=t.t,o=A.b([],p)
if(s)o.push(new A.x('<svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7"/></svg>'))
r=A.D(o,"w-5 h-5 rounded-md flex items-center justify-center border transition-colors cursor-pointer "+r,new A.dt(q,a),null)
return A.d(A.b([A.d(A.b([r,A.a("text-sm "+(s?"line-through text-zinc-500":"text-zinc-200"),a.c)],p),"flex items-center gap-3"),A.D(A.b([new A.x('<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/></svg>')],p),"text-xs text-zinc-500 hover:text-red-400 transition-colors p-1 cursor-pointer",new A.du(q,a),null)],p),"p-3.5 rounded-xl bg-[#14141A] border border-[#27272A] flex items-center justify-between transition-all hover:border-zinc-700")},
$S:24}
A.dt.prototype={
$1(a){var s=this.a.c,r=this.b,q=J.cJ(s.gh(),new A.ds(r),t.V)
q=A.aC(q,q.$ti.i("I.E"))
s.sh(q)
if(!r.a)A.av(0.5,0.5)},
$S:0}
A.ds.prototype={
$1(a){var s=a.b
return s===this.a.b?new A.a3(!a.a,s,a.c):a},
$S:25}
A.du.prototype={
$1(a){var s=this.a.c,r=J.hQ(s.gh(),new A.dr(this.b))
r=A.aC(r,r.$ti.i("e.E"))
s.sh(r)
return r},
$S:0}
A.dr.prototype={
$1(a){return a.b!==this.a.b},
$S:26}
A.dz.prototype={
$1(a){return a.b},
$S:27}
A.dh.prototype={
$1(a){var s=this.a.e,r=s.gh()
s.sh(r-1)
return r},
$S:0}
A.di.prototype={
$1(a){var s=this.a.e,r=s.gh()
s.sh(r+1)
return r},
$S:0}
A.dj.prototype={
$1(a){var s=a.b
if(s==null)s=""
this.a.r.sh(s)
return s},
$S:0}
A.dk.prototype={
$0(){var s,r=this.a
if(r.r.gh().length===0)r=B.f
else{r=r.gaH()
s=r.gh()?"text-emerald-400":"text-amber-400"
r=r.gh()?"\u2713 Valid email syntax":"\u26a0 Invalid email address"
r=A.a("text-xs font-mono "+s,r)}return r},
$S:3}
A.dl.prototype={
$1(a){var s=a.b
if(s==null)s=""
this.a.w.sh(s)
return s},
$S:0}
A.dm.prototype={
$0(){var s,r=this.a
if(r.w.gh().length===0)r=B.f
else{r=r.gaI()
s=r.gh()?"text-emerald-400":"text-amber-400"
r=r.gh()?"\u2713 Strong password length":"\u26a0 Requires at least 8 characters"
r=A.a("text-xs font-mono "+s,r)}return r},
$S:3}
A.dn.prototype={
$1(a){var s=this.a,r=s.gaH().gh()&&s.gaI().gh()
s=s.a
if(r){s.M("Validation Success! Account Ready.")
A.av(0.5,0.5)}else s.M("Please fulfill validation requirements.")},
$S:0}
A.df.prototype={
$1(a){return A.av(0.5,0.5)},
$S:0}
A.dg.prototype={
$1(a){A.av(0.2,0.6)
A.av(0.8,0.6)},
$S:0}
A.dK.prototype={
A(){var s=null,r="hover:text-white transition-colors",q=t.t
return new A.bP("header",s,"sticky top-0 z-50 w-full border-b border-[#1E1E24] bg-[#09090B]/85 backdrop-blur-md",s,s,s,A.b([A.d(A.b([A.d(A.b([A.d(A.b([new A.x('<svg class="w-5 h-5 text-white" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">\n                      <polygon points="12 2 2 7 12 12 22 7 12 2"></polygon>\n                      <polyline points="2 17 12 22 22 17"></polyline>\n                      <polyline points="2 12 12 17 22 12"></polyline>\n                    </svg>')],q),"relative w-9 h-9 rounded-xl bg-gradient-to-br from-indigo-500 via-indigo-600 to-violet-700 p-0.5 shadow-lg shadow-indigo-500/25 flex items-center justify-center"),A.d(A.b([A.a("font-extrabold text-lg text-white tracking-tight","Bloom"),A.a("text-[11px] font-mono font-semibold px-2 py-0.5 rounded-md bg-[#14141A] text-indigo-400 border border-indigo-500/30","JS Native")],q),"flex items-center gap-2.5")],q),"flex items-center gap-3.5"),new A.ca("nav",s,"hidden md:flex items-center gap-8 text-sm text-zinc-400 font-medium",s,s,s,A.b([A.ar(B.a,r,"#features","Architecture"),A.ar(B.a,r,"#benchmark","Telemetry Benchmark"),A.ar(B.a,r,"#code","Code Showcase"),A.ar(B.a,r,"https://github.com/Chidi09/Bloom","Documentation")],q)),A.d(A.b([A.D(A.b([new A.x('<svg class="w-3.5 h-3.5 text-indigo-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>'),A.a(s,"bloom create")],q),"px-3.5 py-1.5 text-xs font-mono rounded-lg bg-[#14141A] hover:bg-[#1E1E24] text-zinc-300 border border-[#27272A] flex items-center gap-2 transition-all cursor-pointer shadow-sm active:scale-95",new A.dL(this),s)],q),"flex items-center gap-4")],q),"max-w-7xl mx-auto px-6 h-16 flex items-center justify-between")],q))}}
A.dL.prototype={
$1(a){return this.a.a.aK()},
$S:0}
A.eY.prototype={
$0(){var s=this.a.r.gh()
if(s==null)return B.f
return A.d(A.b([new A.x('<svg class="w-4 h-4 text-emerald-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>'),A.a("text-xs font-mono text-zinc-200 font-medium",s)],t.t),"fixed bottom-6 right-6 z-50 px-4 py-3 rounded-xl bg-[#14141A] border border-[#27272A] shadow-2xl flex items-center gap-3 animate-bounce")},
$S:3}
A.e_.prototype={
bq(){var s,r,q,p,o,n,m,l,k,j,i,h,g,f,e,d,c,b,a,a0,a1,a2,a3,a4,a5,a6=this
try{a1=a6.a
s=a1.clientWidth>0?a1.clientWidth:900
r=a1.clientHeight>0?a1.clientHeight:600
a2=v.G
q=a2.THREE.Scene()
p=a2.THREE.PerspectiveCamera(45,s/r,0.1,1000)
p.gbN().saO(6)
a3=t.N
a4=t.z
o=A.aL(A.bA(A.q(["canvas",a1,"alpha",!0,"antialias",!0],a3,a4)))
n=a2.THREE.WebGLRenderer(o)
n.aR(s,r)
n.bL(a2.window.devicePixelRatio)
m=a2.THREE.Group()
J.cH(q,m)
l=a2.THREE.IcosahedronGeometry(1.8,2)
k=A.aL(A.bA(A.q(["color",6514417,"wireframe",!0,"transparent",!0,"opacity",0.4],a3,a4)))
j=a2.THREE.MeshBasicMaterial(k)
i=a2.THREE.Mesh(l,j)
J.cH(m,i)
h=a2.THREE.IcosahedronGeometry(1.1,1)
g=A.aL(A.bA(A.q(["color",9133302,"wireframe",!0,"transparent",!0,"opacity",0.25],a3,a4)))
f=a2.THREE.MeshBasicMaterial(g)
e=a2.THREE.Mesh(h,f)
J.cH(m,e)
d=a2.THREE.TorusGeometry(2.4,0.015,16,100)
c=A.aL(A.bA(A.q(["color",440020,"wireframe",!0,"transparent",!0,"opacity",0.15],a3,a4)))
b=a2.THREE.MeshBasicMaterial(c)
a=a2.THREE.Mesh(d,b)
a.gC().sE(1.0471975511965976)
J.cH(m,a)
a6.b=!0
a2.window.onmousemove=A.cD(new A.e1(a6))
a0=new A.e0(a6,i,e,a,m,n,q,p)
a2.window.requestAnimationFrame(A.cD(a0))
a2.window.onresize=A.cD(new A.e2(a6,p,n))}catch(a5){}}}
A.e1.prototype={
$1(a){var s=this.a,r=v.G
s.c=a.clientX/r.window.innerWidth*2-1
s.d=-(a.clientY/r.window.innerHeight)*2+1},
$S:11}
A.e0.prototype={
$1(a){var s,r=this
if(!r.a.b)return
s=r.b.gC()
s.sE(s.gE().L(0,0.002))
s=r.b.gC()
s.sK(s.gK().L(0,0.0035))
s=r.c.gC()
s.sE(s.gE().O(0,0.003))
s=r.c.gC()
s.sK(s.gK().O(0,0.0045))
s=r.d.gC()
s.saO(s.gaO().L(0,0.0015))
s=r.e.gC()
s.sK(s.gK().L(0,B.e.O(r.a.c*0.4,r.e.gC().gK())*0.05))
s=r.e.gC()
s.sE(s.gE().L(0,B.e.O(-r.a.d*0.4,r.e.gC().gE())*0.05))
r.f.bO(r.r,r.w)
v.G.window.requestAnimationFrame(A.cD(r))},
$S:28}
A.e2.prototype={
$1(a){var s,r,q=this.a
if(!q.b)return
q=q.a
s=q.clientWidth
r=q.clientHeight
if(s>0&&r>0){q=this.b
q.sbM(s/r)
q.bP()
this.c.aR(s,r)}},
$S:11}
A.dT.prototype={
aM(a){var s,r,q
this.b.sh(a)
s=J.dE(a,t.S)
for(r=0;r<a;r=q){q=r+1
s[r]=q}this.e.sh(s)},
aK(){this.w.sh(!0)
this.M("Copied: bloom create my_app --target=web_dom")
A.av(0.5,0.3)
A.fE(B.m,new A.dX(this),t.P)},
M(a){this.r.sh(a)
A.fE(B.m,new A.dW(this,a),t.P)},
bh(){A.ip(B.y,new A.dV(this))}}
A.dX.prototype={
$0(){this.a.w.sh(!1)},
$S:2}
A.dW.prototype={
$0(){var s=this.a.r
if(s.gh()===this.b)s.sh(null)},
$S:2}
A.dV.prototype={
$1(a){var s,r,q,p,o=this.a
if(o.f.gh()){s=o.e
r=s.gh()
q=new A.dZ()
$.fu()
p=$.dQ.$0()
q.a=p
q.b=null
p=J.cJ(r,new A.dU(),t.S)
p=A.aC(p,p.$ti.i("I.E"))
s.sh(p)
s=$.dQ.$0()
q.b=s
o.d.sh(A.jK(B.e.bI(q.gbn()/1000,2)))}},
$S:29}
A.dU.prototype={
$1(a){return B.b.ac(a,99)+1},
$S:30}
A.aR.prototype={
a5(){var s,r,q,p,o,n,m,l=this,k=l.at&=4294967293
if((k&1)!==0)return!1
if((k&36)===32)return!0
k&=4294967291
l.at=k
p=l.as
o=$.eL
if(p===o)return!0
l.as=o
l.at=k|1
s=A.he(l)
if(l.e>0&&!s){l.at&=4294967294
return!0}n=$.C
try{A.hg(l)
$.C=l
r=l.z.$0()
if((l.at&16)!==0||s||l.e===0){if(l.e!==0){k=l.y
k===$&&A.a8()
k=!J.aq(r,k)}else k=!0
if(k){k=l.e
if(k!==0)l.y===$&&A.a8()
l.y=r
l.at&=4294967279
l.e=k+1}}}catch(m){q=A.a9(m)
l.ax=q
l.at|=16;++l.e}$.C=n
A.h7(l)
l.at&=4294967294
return!0},
W(a){var s,r=this
if(r.r==null){r.at|=36
for(s=r.Q;s!=null;s=s.c)s.a.W(s)}r.aU(a)},
I(a){var s=this
if(s.r!=null){s.ad(a)
if(s.r==null){s.at&=4294967263
for(a=s.Q;a!=null;a=a.c)a.a.I(a)}}},
aq(){var s=this.at
if((s&2)===0){this.at=s|6
this.ar()}},
gh(){var s,r,q=this
if(q.b){A.hv("computed warning: ["+q.d+"|"+A.o(q.c)+"] has been read after disposed: "+A.fb().j(0))
s=q.y
s===$&&A.a8()
return s}if((q.at&1)!==0)throw A.f(new A.ax())
r=A.h2(q)
q.a5()
if(r!=null)r.r=q.e
if((q.at&16)!==0){s=q.ax
s.toString
throw A.f(s)}s=q.y
s===$&&A.a8()
return s},
gp(){return this.Q},
gam(){return this.at},
sp(a){return this.Q=a}}
A.bJ.prototype={
aW(a,b){var s
try{this.ah()}catch(s){this.aD()
throw s}},
ah(){var s,r,q=this,p=q.bg()
try{if((q.r&8)!==0)return
r=q.a
if(r==null)return
s=r.$0()
if(t.Z.b(s))q.d=s}finally{p.$0()}},
bg(){var s,r=this,q=r.r
if((q&1)!==0)throw A.f(new A.ax())
q|=1
r.r=q
r.r=q&4294967287
A.h6(r)
A.hg(r)
$.X=$.X+1
s=$.C
$.C=r
return new A.d0(r,s)},
aq(){var s=this,r=s.r
if((r&2)===0){s.r=r|2
s.f=$.eC
$.eC=s}},
aD(){var s,r,q,p=this
if(p.x)return
if(((p.r|=8)&1)===0)A.fi(p)
for(s=p.w,s=A.fS(s,s.r,s.$ti.c),r=s.$ti.c;s.k();){q=s.d;(q==null?r.a(q):q).$0()}p.x=!0},
gp(){return this.e},
gam(){return this.r},
sp(a){return this.e=a}}
A.d0.prototype={
$0(){var s=this.a
if($.C!==s)A.f0(A.fC("Out-of-order effect"))
A.h7(s)
$.C=this.b
if(((s.r&=4294967294)&8)!==0)A.fi(s)
A.fj()
return null},
$S:1}
A.aF.prototype={
ar(){for(var s=this.r;s!=null;s=s.f)s.d.aq()},
j(a){return A.o(this.gh())},
$0(){return this.gh()},
W(a){var s=this.r
if(s!==a&&a.e==null){a.f=s
if(s!=null)s.e=a
this.r=a}},
I(a){var s,r,q=this.r
if(q!=null){s=a.e
r=a.f
if(s!=null){s.f=r
a.e=null}if(r!=null){r.e=s
a.f=null}if(a===q)this.r=r}}}
A.b9.prototype={
a5(){return!0},
I(a){this.ad(a)},
aQ(a){var s=this,r=s.Q
r===$&&A.a8()
r=s.as.$2(a,r)
if(r)return!1
if($.eK>100)throw A.f(new A.ax())
r=s.Q
r===$&&A.a8()
if(a==null?r!=null:a!==r){if(r==null)s.z===$&&A.a8()
s.Q=a}++s.e
$.eL=$.eL+1
$.X=$.X+1
try{s.ar()}finally{A.fj()}return!0},
sh(a){if(this.b)throw A.f(new A.cn("A "+A.hr(this).j(0)+" signal was written after being disposed.\nOnce you have called dispose() on a signal, it can no longer be used."))
this.aQ(a)},
gh(){var s,r,q=this
if(q.b){A.hv("signal warning: ["+q.d+"|"+A.o(q.c)+"] has been read after disposed: "+A.fb().j(0))
s=q.Q
s===$&&A.a8()
return s}r=A.h2(q)
if(r!=null)r.r=q.e
s=q.Q
s===$&&A.a8()
return s}}
A.dY.prototype={
$2(a,b){return a==null?b==null:a===b},
$S(){return this.a.i("v(0,0)")}}
A.eq.prototype={}
A.cm.prototype={
j(a){return this.a}}
A.cn.prototype={}
A.ax.prototype={};(function aliases(){var s=J.a_.prototype
s.aT=s.j
s=A.aF.prototype
s.aU=s.W
s.ad=s.I})();(function installTearOffs(){var s=hunkHelpers._static_0,r=hunkHelpers._static_1,q=hunkHelpers._instance_0u
s(A,"jq","ic",7)
r(A,"jF","ir",6)
r(A,"jG","is",6)
r(A,"jH","it",6)
s(A,"hm","jy",1)
q(A.bJ.prototype,"gbm","aD",1)})();(function inheritance(){var s=hunkHelpers.mixin,r=hunkHelpers.inherit,q=hunkHelpers.inheritMany
r(A.j,null)
q(A.j,[A.f8,J.bR,A.b8,J.bD,A.p,A.dS,A.e,A.aB,A.c0,A.cu,A.aT,A.bn,A.Y,A.e4,A.dM,A.bK,A.bq,A.a1,A.dH,A.bX,A.bY,A.bW,A.dF,A.J,A.cx,A.ex,A.br,A.P,A.cy,A.K,A.cv,A.eA,A.cz,A.aG,A.ep,A.aK,A.r,A.aw,A.cb,A.ba,A.ee,A.d5,A.ag,A.B,A.cB,A.dZ,A.cq,A.as,A.l,A.cV,A.bo,A.bh,A.cK,A.cW,A.d2,A.d8,A.de,A.dK,A.e_,A.dT,A.aF,A.bJ,A.eq])
q(J.bR,[J.bT,J.aY,J.b0,J.b_,J.b1,J.aZ,J.az])
q(J.b0,[J.a_,J.t,A.aD,A.b5])
q(J.a_,[J.cd,J.bb,J.Z])
r(J.bS,A.b8)
r(J.dG,J.t)
q(J.aZ,[J.aX,J.bU])
q(A.p,[A.b2,A.U,A.bV,A.ct,A.cj,A.cw,A.bE,A.O,A.bc,A.cs,A.co,A.bI,A.cm,A.ax])
q(A.e,[A.i,A.S,A.W])
q(A.i,[A.I,A.af,A.ae,A.bf])
r(A.aa,A.S)
r(A.T,A.I)
r(A.cA,A.bn)
r(A.a3,A.cA)
q(A.Y,[A.bG,A.bH,A.cr,A.eT,A.eV,A.eb,A.ea,A.em,A.eu,A.eX,A.eG,A.eB,A.cO,A.cQ,A.cR,A.cL,A.cZ,A.cX,A.da,A.dp,A.dv,A.dw,A.dy,A.dt,A.ds,A.du,A.dr,A.dz,A.dh,A.di,A.dj,A.dl,A.dn,A.df,A.dg,A.dL,A.e1,A.e0,A.e2,A.dV,A.dU])
q(A.bG,[A.dO,A.ec,A.ed,A.ew,A.ev,A.d6,A.ef,A.ei,A.eh,A.eg,A.el,A.ek,A.ej,A.et,A.eO,A.eF,A.eE,A.eD,A.eJ,A.eI,A.eH,A.cM,A.cN,A.cP,A.cS,A.cT,A.cU,A.d_,A.cY,A.d9,A.dC,A.dB,A.dD,A.dA,A.dq,A.dx,A.dk,A.dm,A.eY,A.dX,A.dW,A.d0])
r(A.b7,A.U)
q(A.cr,[A.cp,A.at])
q(A.a1,[A.ad,A.be])
q(A.bH,[A.eU,A.en,A.dJ,A.dY])
q(A.b5,[A.c1,A.aE])
q(A.aE,[A.bj,A.bl])
r(A.bk,A.bj)
r(A.b3,A.bk)
r(A.bm,A.bl)
r(A.b4,A.bm)
q(A.b3,[A.c2,A.c3])
q(A.b4,[A.c4,A.c5,A.c6,A.c7,A.c8,A.b6,A.c9])
r(A.bs,A.cw)
r(A.es,A.eA)
r(A.bg,A.be)
r(A.bp,A.aG)
r(A.bi,A.bp)
r(A.ch,A.O)
q(A.l,[A.aS,A.aV,A.bZ,A.aU,A.ci])
r(A.ab,A.aV)
r(A.A,A.bZ)
r(A.ay,A.aU)
r(A.x,A.ci)
q(A.aS,[A.R,A.aH,A.cc,A.bM,A.bN,A.bO,A.au,A.bQ,A.bC,A.bP,A.bL,A.c_,A.ca,A.ck,A.ce])
q(A.aF,[A.aR,A.b9])
r(A.cn,A.cm)
s(A.bj,A.r)
s(A.bk,A.aT)
s(A.bl,A.r)
s(A.bm,A.aT)})()
var v={G:typeof self!="undefined"?self:globalThis,typeUniverse:{eC:new Map(),tR:{},eT:{},tPV:{},sEA:[]},mangledGlobalNames:{c:"int",n:"double",ht:"num",h:"String",v:"bool",B:"Null",k:"List",j:"Object",a0:"Map",u:"JSObject"},mangledNames:{},types:["~(as)","~()","B()","l()","aH()","v()","~(~())","c()","B(@)","x()","au()","B(u)","@(@)","@(@,h)","@(h)","B(~())","B(j,aI)","~(j?,j?)","j?(j?)","v(h)","~(u)","ab()","R(c)","k<+done,id,text(v,h,h)>()","R(+done,id,text(v,h,h))","+done,id,text(v,h,h)(+done,id,text(v,h,h))","v(+done,id,text(v,h,h))","h(+done,id,text(v,h,h))","~(n)","~(e3)","c(c)"],interceptorsByTag:null,leafTags:null,arrayRti:Symbol("$ti"),rttc:{"3;done,id,text":(a,b,c)=>d=>d instanceof A.a3&&a.b(d.a)&&b.b(d.b)&&c.b(d.c)}}
A.iL(v.typeUniverse,JSON.parse('{"cd":"a_","bb":"a_","Z":"a_","k2":"aD","bT":{"v":[],"m":[]},"aY":{"B":[],"m":[]},"b0":{"u":[]},"a_":{"u":[]},"t":{"k":["1"],"i":["1"],"u":[],"e":["1"]},"bS":{"b8":[]},"dG":{"t":["1"],"k":["1"],"i":["1"],"u":[],"e":["1"]},"aZ":{"n":[]},"aX":{"n":[],"c":[],"m":[]},"bU":{"n":[],"m":[]},"az":{"h":[],"m":[]},"b2":{"p":[]},"i":{"e":["1"]},"I":{"i":["1"],"e":["1"]},"S":{"e":["2"],"e.E":"2"},"aa":{"S":["1","2"],"i":["2"],"e":["2"],"e.E":"2"},"T":{"I":["2"],"i":["2"],"e":["2"],"e.E":"2","I.E":"2"},"W":{"e":["1"],"e.E":"1"},"b7":{"U":[],"p":[]},"bV":{"p":[]},"ct":{"p":[]},"bq":{"aI":[]},"Y":{"ac":[]},"bG":{"ac":[]},"bH":{"ac":[]},"cr":{"ac":[]},"cp":{"ac":[]},"at":{"ac":[]},"cj":{"p":[]},"ad":{"a1":["1","2"],"a0":["1","2"]},"af":{"i":["1"],"e":["1"],"e.E":"1"},"ae":{"i":["ag<1,2>"],"e":["ag<1,2>"],"e.E":"ag<1,2>"},"aD":{"u":[],"f3":[],"m":[]},"b5":{"u":[]},"c1":{"f4":[],"u":[],"m":[]},"aE":{"E":["1"],"u":[]},"b3":{"r":["n"],"k":["n"],"E":["n"],"i":["n"],"u":[],"e":["n"]},"b4":{"r":["c"],"k":["c"],"E":["c"],"i":["c"],"u":[],"e":["c"]},"c2":{"d3":[],"r":["n"],"k":["n"],"E":["n"],"i":["n"],"u":[],"e":["n"],"m":[],"r.E":"n"},"c3":{"d4":[],"r":["n"],"k":["n"],"E":["n"],"i":["n"],"u":[],"e":["n"],"m":[],"r.E":"n"},"c4":{"db":[],"r":["c"],"k":["c"],"E":["c"],"i":["c"],"u":[],"e":["c"],"m":[],"r.E":"c"},"c5":{"dc":[],"r":["c"],"k":["c"],"E":["c"],"i":["c"],"u":[],"e":["c"],"m":[],"r.E":"c"},"c6":{"dd":[],"r":["c"],"k":["c"],"E":["c"],"i":["c"],"u":[],"e":["c"],"m":[],"r.E":"c"},"c7":{"e6":[],"r":["c"],"k":["c"],"E":["c"],"i":["c"],"u":[],"e":["c"],"m":[],"r.E":"c"},"c8":{"e7":[],"r":["c"],"k":["c"],"E":["c"],"i":["c"],"u":[],"e":["c"],"m":[],"r.E":"c"},"b6":{"e8":[],"r":["c"],"k":["c"],"E":["c"],"i":["c"],"u":[],"e":["c"],"m":[],"r.E":"c"},"c9":{"e9":[],"r":["c"],"k":["c"],"E":["c"],"i":["c"],"u":[],"e":["c"],"m":[],"r.E":"c"},"cw":{"p":[]},"bs":{"U":[],"p":[]},"br":{"e3":[]},"P":{"p":[]},"K":{"aW":["1"]},"be":{"a1":["1","2"],"a0":["1","2"]},"bg":{"be":["1","2"],"a1":["1","2"],"a0":["1","2"]},"bf":{"i":["1"],"e":["1"],"e.E":"1"},"bi":{"aG":["1"],"i":["1"],"e":["1"]},"a1":{"a0":["1","2"]},"aG":{"i":["1"],"e":["1"]},"bp":{"aG":["1"],"i":["1"],"e":["1"]},"k":{"i":["1"],"e":["1"]},"bE":{"p":[]},"U":{"p":[]},"O":{"p":[]},"ch":{"p":[]},"bc":{"p":[]},"cs":{"p":[]},"co":{"p":[]},"bI":{"p":[]},"cb":{"p":[]},"ba":{"p":[]},"cB":{"aI":[]},"ab":{"l":[]},"x":{"l":[]},"R":{"l":[]},"aH":{"l":[]},"au":{"l":[]},"aS":{"l":[]},"aV":{"l":[]},"bZ":{"l":[]},"aU":{"l":[]},"ci":{"l":[]},"A":{"l":[]},"ay":{"aU":["1"],"l":[]},"cc":{"l":[]},"bM":{"l":[]},"bN":{"l":[]},"bO":{"l":[]},"bQ":{"l":[]},"bC":{"l":[]},"bP":{"l":[]},"bL":{"l":[]},"c_":{"l":[]},"ca":{"l":[]},"ck":{"l":[]},"ce":{"l":[]},"aR":{"aF":["1"]},"b9":{"aF":["1"]},"cm":{"p":[]},"cn":{"p":[]},"ax":{"p":[]},"dd":{"k":["c"],"i":["c"],"e":["c"]},"e9":{"k":["c"],"i":["c"],"e":["c"]},"e8":{"k":["c"],"i":["c"],"e":["c"]},"db":{"k":["c"],"i":["c"],"e":["c"]},"e6":{"k":["c"],"i":["c"],"e":["c"]},"dc":{"k":["c"],"i":["c"],"e":["c"]},"e7":{"k":["c"],"i":["c"],"e":["c"]},"d3":{"k":["n"],"i":["n"],"e":["n"]},"d4":{"k":["n"],"i":["n"],"e":["n"]}}'))
A.iK(v.typeUniverse,JSON.parse('{"i":1,"cu":1,"aT":1,"bX":1,"bY":1,"aE":1,"bp":1}'))
var u={c:"Error handler must accept one Object or one Object and a StackTrace as arguments, and return a value of the returned future's type",d:"text-3xl sm:text-4xl font-bold text-white mt-2 mb-4",a:"text-xs font-mono text-indigo-400 font-semibold uppercase tracking-wider"}
var t=(function rtii(){var s=A.eR
return{c:s("l"),J:s("f3"),Y:s("f4"),_:s("R"),W:s("i<@>"),Q:s("p"),B:s("d3"),q:s("d4"),a:s("ay<+done,id,text(v,h,h)>"),Z:s("ac"),d:s("db"),k:s("dc"),U:s("dd"),e:s("e<@>"),t:s("t<l>"),O:s("t<u>"),x:s("t<a0<h,j>>"),f:s("t<+done,id,text(v,h,h)>"),s:s("t<h>"),h:s("t<bh>"),n:s("t<n>"),b:s("t<@>"),T:s("aY"),m:s("u"),g:s("Z"),p:s("E<@>"),r:s("k<j>"),w:s("k<+done,id,text(v,h,h)>"),j:s("k<@>"),L:s("k<c>"),D:s("a0<h,j>"),E:s("a0<h,a0<h,j>>"),P:s("B"),K:s("j"),G:s("k3"),F:s("+()"),V:s("+done,id,text(v,h,h)"),l:s("aI"),N:s("h"),ae:s("e3"),R:s("m"),b7:s("U"),c0:s("e6"),bk:s("e7"),ca:s("e8"),bX:s("e9"),o:s("bb"),A:s("bg<j?,j?>"),cl:s("bh"),y:s("v"),i:s("n"),z:s("@"),v:s("@(j)"),C:s("@(j,aI)"),S:s("c"),bc:s("aW<B>?"),aQ:s("u?"),X:s("j?"),u:s("h?"),cG:s("v?"),I:s("n?"),a3:s("c?"),be:s("ht?"),H:s("ht"),b9:s("~"),M:s("~()"),co:s("~(as)")}})();(function constants(){var s=hunkHelpers.makeConstList
B.z=J.bR.prototype
B.h=J.t.prototype
B.b=J.aX.prototype
B.e=J.aZ.prototype
B.d=J.az.prototype
B.A=J.Z.prototype
B.B=J.b0.prototype
B.n=J.cd.prototype
B.i=J.bb.prototype
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

B.v=new A.cb()
B.l=new A.dS()
B.c=new A.es()
B.w=new A.cB()
B.x=new A.aw(0)
B.m=new A.aw(3e6)
B.y=new A.aw(6e4)
B.a=s([],t.t)
B.f=new A.ab(B.a)
B.C=A.L("f3")
B.D=A.L("f4")
B.E=A.L("d3")
B.F=A.L("d4")
B.G=A.L("db")
B.H=A.L("dc")
B.I=A.L("dd")
B.J=A.L("j")
B.K=A.L("e6")
B.L=A.L("e7")
B.M=A.L("e8")
B.N=A.L("e9")})();(function staticFields(){$.eo=null
$.ak=A.b([],A.eR("t<j>"))
$.fI=null
$.dP=0
$.dQ=A.jq()
$.fz=null
$.fy=null
$.hs=null
$.hl=null
$.hw=null
$.eQ=null
$.eW=null
$.fq=null
$.er=A.b([],A.eR("t<k<j>?>"))
$.aM=null
$.bx=null
$.bz=null
$.fl=!1
$.w=B.c
$.eL=0
$.C=null
$.eC=null
$.X=0
$.eK=0
$.by=0})();(function lazyInitializers(){var s=hunkHelpers.lazyFinal
s($,"k1","hA",()=>A.eS("_$dart_dartClosure"))
s($,"k0","ft",()=>A.eS("_$dart_dartClosure_dartJSInterop"))
s($,"ki","hM",()=>A.b([new J.bS()],A.eR("t<b8>")))
s($,"k6","hC",()=>A.V(A.e5({
toString:function(){return"$receiver$"}})))
s($,"k7","hD",()=>A.V(A.e5({$method$:null,
toString:function(){return"$receiver$"}})))
s($,"k8","hE",()=>A.V(A.e5(null)))
s($,"k9","hF",()=>A.V(function(){var $argumentsExpr$="$arguments$"
try{null.$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"kc","hI",()=>A.V(A.e5(void 0)))
s($,"kd","hJ",()=>A.V(function(){var $argumentsExpr$="$arguments$"
try{(void 0).$method$($argumentsExpr$)}catch(r){return r.message}}()))
s($,"kb","hH",()=>A.V(A.fN(null)))
s($,"ka","hG",()=>A.V(function(){try{null.$method$}catch(r){return r.message}}()))
s($,"kf","hL",()=>A.V(A.fN(void 0)))
s($,"ke","hK",()=>A.V(function(){try{(void 0).$method$}catch(r){return r.message}}()))
s($,"kg","fv",()=>A.iq())
s($,"kh","f1",()=>A.f_(B.J))
s($,"k5","fu",()=>{A.ie()
return $.dP})
s($,"k4","hB",()=>A.ik())})();(function nativeSupport(){!function(){var s=function(a){var m={}
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
hunkHelpers.setOrUpdateInterceptorsByTag({ArrayBuffer:A.aD,SharedArrayBuffer:A.aD,ArrayBufferView:A.b5,DataView:A.c1,Float32Array:A.c2,Float64Array:A.c3,Int16Array:A.c4,Int32Array:A.c5,Int8Array:A.c6,Uint16Array:A.c7,Uint32Array:A.c8,Uint8ClampedArray:A.b6,CanvasPixelArray:A.b6,Uint8Array:A.c9})
hunkHelpers.setOrUpdateLeafTags({ArrayBuffer:true,SharedArrayBuffer:true,ArrayBufferView:false,DataView:true,Float32Array:true,Float64Array:true,Int16Array:true,Int32Array:true,Int8Array:true,Uint16Array:true,Uint32Array:true,Uint8ClampedArray:true,CanvasPixelArray:true,Uint8Array:false})
A.aE.$nativeSuperclassTag="ArrayBufferView"
A.bj.$nativeSuperclassTag="ArrayBufferView"
A.bk.$nativeSuperclassTag="ArrayBufferView"
A.b3.$nativeSuperclassTag="ArrayBufferView"
A.bl.$nativeSuperclassTag="ArrayBufferView"
A.bm.$nativeSuperclassTag="ArrayBufferView"
A.b4.$nativeSuperclassTag="ArrayBufferView"})()
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
var s=A.jU
if(typeof dartMainRunner==="function"){dartMainRunner(s,[])}else{s([])}})})()
//# sourceMappingURL=main.js.map
