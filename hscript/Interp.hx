/*
 * Copyright (c) 2008, Nicolas Cannasse
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *   - Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *   - Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE HAXE PROJECT CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE HAXE PROJECT CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
 * DAMAGE.
 */
package hscript;
import hscript.Expr;

private enum Stop {
	SBreak;
	SContinue;
	SReturn( v : Dynamic );
}

class Interp {

	public var variables : Hash<Dynamic>;
	var locals : Hash<{ r : Dynamic }>;
	var binops : Hash<Expr -> Expr -> Dynamic>;
	var declared : Array<{ n : String, old : { r : Dynamic } }>;

	public function new() {
		locals = new Hash();
		declared = new Array();
		variables = new Hash();
		variables.set("null",null);
		variables.set("true",true);
		variables.set("false",false);
		#if hscriptPos
		variables.set("_trace_",function(e, f, l) {
			haxe.Log.trace(Std.string(e),cast { fileName : f, lineNumber : l });
		});
		#else
		variables.set("trace",function(e) {
			haxe.Log.trace(Std.string(e),cast { fileName : "hscript", lineNumber : 0 });
		});
		#end
		initOps();
	}

	function initOps() {
		var me = this;
		binops = new Hash();
		binops.set("+",function(e1,e2) return me.expr(e1) + me.expr(e2));
		binops.set("-",function(e1,e2) return me.expr(e1) - me.expr(e2));
		binops.set("*",function(e1,e2) return me.expr(e1) * me.expr(e2));
		binops.set("/",function(e1,e2) return me.expr(e1) / me.expr(e2));
		binops.set("%",function(e1,e2) return me.expr(e1) % me.expr(e2));
		binops.set("&",function(e1,e2) return me.expr(e1) & me.expr(e2));
		binops.set("|",function(e1,e2) return me.expr(e1) | me.expr(e2));
		binops.set("^",function(e1,e2) return me.expr(e1) ^ me.expr(e2));
		binops.set("<<",function(e1,e2) return me.expr(e1) << me.expr(e2));
		binops.set(">>",function(e1,e2) return me.expr(e1) >> me.expr(e2));
		binops.set(">>>",function(e1,e2) return me.expr(e1) >>> me.expr(e2));
		binops.set("==",function(e1,e2) return me.expr(e1) == me.expr(e2));
		binops.set("!=",function(e1,e2) return me.expr(e1) != me.expr(e2));
		binops.set(">=",function(e1,e2) return me.expr(e1) >= me.expr(e2));
		binops.set("<=",function(e1,e2) return me.expr(e1) <= me.expr(e2));
		binops.set(">",function(e1,e2) return me.expr(e1) > me.expr(e2));
		binops.set("<",function(e1,e2) return me.expr(e1) < me.expr(e2));
		binops.set("||",function(e1,e2) return me.expr(e1) == true || me.expr(e2) == true);
		binops.set("&&",function(e1,e2) return me.expr(e1) == true && me.expr(e2) == true);
		binops.set("=",assign);
		binops.set("...",function(e1,e2) return new IntIter(me.expr(e1),me.expr(e2)));
		assignOp("+=",function(v1:Dynamic,v2:Dynamic) return v1 + v2);
		assignOp("-=",function(v1:Float,v2:Float) return v1 - v2);
		assignOp("*=",function(v1:Float,v2:Float) return v1 * v2);
		assignOp("/=",function(v1:Float,v2:Float) return v1 / v2);
		assignOp("%=",function(v1:Float,v2:Float) return v1 % v2);
		assignOp("&=",function(v1,v2) return v1 & v2);
		assignOp("|=",function(v1,v2) return v1 | v2);
		assignOp("^=",function(v1,v2) return v1 ^ v2);
		assignOp("<<=",function(v1,v2) return v1 << v2);
		assignOp(">>=",function(v1,v2) return v1 >> v2);
		assignOp(">>>=",function(v1,v2) return v1 >>> v2);
	}

	function assign( e1 : Expr, e2 : Expr ) : Dynamic {
		var v = expr(e2);
		switch( #if hscriptPos e1.e #else e1 #end ) {
		case EIdent(id):
			var l = locals.get(id);
			if( l == null )
				variables.set(id,v)
			else
				l.r = v;
		case EField(e,f):
			v = set(expr(e),f,v,e);
		case EArray(e,index):
			expr(e)[expr(index)] = v;
		default: throw Error.InExpr(ErrorDef.EInvalidOp("="), e1);
		}
		return v;
	}

	function assignOp( op, fop : Dynamic -> Dynamic -> Dynamic ) {
		var me = this;
		binops.set(op,function(e1,e2) return me.evalAssignOp(op,fop,e1,e2));
	}

	function evalAssignOp(op,fop,e1:Expr,e2) : Dynamic {
		var v;
		switch( #if hscriptPos e1.e #else e1 #end ) {
		case EIdent(id):
			var l = locals.get(id);
			v = fop(expr(e1),expr(e2));
			if( l == null )
				variables.set(id,v)
			else
				l.r = v;
		case EField(e,f):
			var obj = expr(e);
			v = fop(get(obj,f,e),expr(e2));
			v = set(obj,f,v,e);
		case EArray(e,index):
			var arr = expr(e);
			var index = expr(index);
			v = fop(arr[index],expr(e2));
			arr[index] = v;
		default:
			throw Error.InExpr(ErrorDef.EInvalidOp(op), e1); //FIXME
		}
		return v;
	}

	function increment( e : Expr, prefix : Bool, delta : Int ) : Dynamic {
		switch(#if hscriptPos e.e #else e #end) {
		case EIdent(id):
			var l = locals.get(id);
			var v : Dynamic = (l == null) ? variables.get(id) : l.r;
			if( prefix ) {
				v += delta;
				if( l == null ) variables.set(id,v) else l.r = v;
			} else
				if( l == null ) variables.set(id,v + delta) else l.r = v + delta;
			return v;
		case EField(e,f):
			var obj = expr(e);
			var v : Dynamic = get(obj,f,e);
			if( prefix ) {
				v += delta;
				set(obj,f,v,e);
			} else
				set(obj,f,v + delta,e);
			return v;
		case EArray(e,index):
			var arr = expr(e);
			var index = expr(index);
			var v = arr[index];
			if( prefix ) {
				v += delta;
				arr[index] = v;
			} else
				arr[index] = v + delta;
			return v;
		default:
			throw Error.InExpr(ErrorDef.EInvalidOp((delta > 0)?"++":"--"), e);
		}
	}

	public function execute( expr : Expr ) : Dynamic {
		locals = new Hash();
		return exprReturn(expr);
	}

	function exprReturn(e) : Dynamic {
		try {
			return expr(e);
		} catch( ee : Stop ) {
			switch( ee ) {
			case SBreak: throw Error.InExpr(ErrorDef.EInvalidStmt("break"), e);
			case SContinue: throw Error.InExpr(ErrorDef.EInvalidStmt("continue"), e);
			case SReturn(v): return v;
			}
		}
		return null;
	}

	function duplicate<T>( h : Hash<T> ) {
		var h2 = new Hash();
		for( k in h.keys() )
			h2.set(k,h.get(k));
		return h2;
	}

	function restore( old : Int ) {
		while( declared.length > old ) {
			var d = declared.pop();
			locals.set(d.n,d.old);
		}
	}

	public function expr( e : Expr ) : Dynamic {
		switch( #if hscriptPos e.e #else e #end ) {
		case EConst(c):
			switch( c ) {
			case CInt(v): return v;
			case CInt32(v): return v;
			case CFloat(f): return f;
			case CString(s): return s;
			}
		case EIdent(id):
			var l = locals.get(id);
			if( l != null )
				return l.r;
			var v = variables.get(id);
			if( v == null && !variables.exists(id) )
				throw Error.InExpr(ErrorDef.EUnknownVariable(id), e);
			return v;
		case EVar(n,_,e):
			declared.push({ n : n, old : locals.get(n) });
			locals.set(n,{ r : (e == null)?null:expr(e) });
			return null;
		case EParent(e):
			return expr(e);
		case EBlock(exprs):
			var old = declared.length;
			var v = null;
			for( e in exprs )
				v = expr(e);
			restore(old);
			return v;
		case EField(e,f):
			return get(expr(e),f,e);
		case EBinop(op,e1,e2):
			var fop = binops.get(op);
			if( fop == null ) throw Error.InExpr(ErrorDef.EInvalidOp(op), e);
			return fop(e1,e2);
		case EUnop(op,prefix,e):
			switch(op) {
			case "!":
				return expr(e) != true;
			case "-":
				return -expr(e);
			case "++":
				return increment(e,prefix,1);
			case "--":
				return increment(e,prefix,-1);
			case "~":
				#if neko
				return haxe.Int32.complement(expr(e));
				#else
				return ~expr(e);
				#end
			default:
				throw Error.InExpr(ErrorDef.EInvalidOp(op), e);
			}
		case ECall(e,params):
			var args = new Array();
			for( p in params )
				args.push(expr(p));
			switch(#if hscriptPos e.e #else e #end) {
			case EField(e,f):
				var obj = expr(e);
				if( obj == null ) throw Error.InExpr(ErrorDef.EInvalidAccess(f), e);
				var fi = Reflect.field(obj,f);
				if ( fi == null || !Reflect.isFunction(fi) ) throw Error.InExpr(ErrorDef.EInvalidAccess(f), e);
				return call(obj,fi,args,e);
			default:
				return call(null,expr(e),args,e);
			}
		case EIf(econd,e1,e2):
			return if( expr(econd) == true ) expr(e1) else if( e2 == null ) null else expr(e2);
		case EWhile(econd,e):
			whileLoop(econd,e);
			return null;
		case EFor(v,it,e):
			forLoop(v,it,e);
			return null;
		case EBreak:
			throw SBreak;
		case EContinue:
			throw SContinue;
		case EReturn(e):
			throw SReturn((e == null)?null:expr(e));
		case EFunction(params,fexpr,name,_):
			var capturedLocals = duplicate(locals);
			var me = this;
			var f = function(args:Array<Dynamic>) {
				if( args.length != params.length ) throw Error.InExpr(ErrorDef.EUnmatchedParameters(params.length, args.length), e);
				var old = me.locals;
				me.locals = me.duplicate(capturedLocals);
				for( i in 0...params.length )
					me.locals.set(params[i].name,{ r : args[i] });
				var r = null;
				try {
					r = me.exprReturn(fexpr);
				} catch( e : Dynamic ) {
					me.locals = old;
					#if neko
					neko.Lib.rethrow(e);
					#else
					throw e;
					#end
				}
				me.locals = old;
				return r;
			};
			var f = Reflect.makeVarArgs(f);
			if( name != null )
				variables.set(name,f);
			return f;
		case EArrayDecl(arr):
			var a = new Array();
			for( e in arr )
				a.push(expr(e));
			return a;
		case EArray(e,index):
			return expr(e)[expr(index)];
		case ENew(cl,params):
			var a = new Array();
			for( e in params )
				a.push(expr(e));
			return cnew(cl,a);
		case EThrow(e):
			throw expr(e);
		case ETry(e,n,_,ecatch):
			var old = declared.length;
			try {
				var v : Dynamic = expr(e);
				restore(old);
				return v;
			} catch( err : Stop ) {
				throw err;
			} catch( err : Dynamic ) {
				// restore vars
				restore(old);
				// declare 'v'
				declared.push({ n : n, old : locals.get(n) });
				locals.set(n,{ r : err });
				var v : Dynamic = expr(ecatch);
				restore(old);
				return v;
			}
		case EObject(fl):
			var o = {};
			for( f in fl )
				set(o,f.name,expr(f.e),e);
			return o;
		case ETernary(econd,e1,e2):
			return if( expr(econd) == true ) expr(e1) else expr(e2);
		}
		return null;
	}

	function whileLoop(econd,e) {
		var old = declared.length;
		while( expr(econd) == true ) {
			try {
				expr(e);
			} catch( err : Stop ) {
				switch(err) {
				case SContinue:
				case SBreak: break;
				case SReturn(_): throw err;
				}
			}
		}
		restore(old);
	}

	function makeIterator( v : Dynamic ) : Iterator<Dynamic> {
		#if (flash && !flash9)
		if( v.iterator != null ) v = v.iterator();
		#else
		try v = v.iterator() catch( e : Dynamic ) {};
		#end
		if( v.hasNext == null || v.next == null ) throw Error.InExpr(ErrorDef.EInvalidIterator(v), null);
		return v;
	}

	function forLoop(n,it,e) {
		var old = declared.length;
		declared.push({ n : n, old : locals.get(n) });
		var it = makeIterator(expr(it));
		while( it.hasNext() ) {
			locals.set(n,{ r : it.next() });
			try {
				expr(e);
			} catch( err : Stop ) {
				switch( err ) {
				case SContinue:
				case SBreak: break;
				case SReturn(_): throw err;
				}
			}
		}
		restore(old);
	}

	function get( o : Dynamic, f : String , ?e : Expr = null ) : Dynamic {
		if( o == null ) throw Error.InExpr(ErrorDef.EInvalidAccess(f), e);
		return Reflect.field(o,f);
	}

	function set( o : Dynamic, f : String, v : Dynamic , ?e : Expr = null ) : Dynamic {
		if( o == null ) throw Error.InExpr(ErrorDef.EInvalidAccess(f), e);
		Reflect.setField(o,f,v);
		return v;
	}

	function call( o : Dynamic, f : Dynamic, args : Array<Dynamic> , ?e : Expr = null ) : Dynamic {
		return Reflect.callMethod(o,f,args);
	}

	function cnew( cl : String, args : Array<Dynamic> ) : Dynamic {
		return Type.createInstance(Type.resolveClass(cl),args);
	}

}
