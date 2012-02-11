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

enum Const {
	CInt( v : Int );
	CFloat( f : Float );
	CString( s : String );
	CInt32( v : haxe.Int32 );
}

#if hscriptPos
typedef Expr = {
	var e : ExprDef;
	var file : String;
	var pmin : Int;
	var pmax : Int;
}
enum ExprDef {
#else
enum Expr {
#end
	EConst( c : Const );
	EIdent( v : String );
	EVar( n : String, ?t : CType, ?e : Expr );
	EParent( e : Expr );
	EBlock( e : Array<Expr> );
	EField( e : Expr, f : String );
	EBinop( op : String, e1 : Expr, e2 : Expr );
	EUnop( op : String, prefix : Bool, e : Expr );
	ECall( e : Expr, params : Array<Expr> );
	EIf( cond : Expr, e1 : Expr, ?e2 : Expr );
	EWhile( cond : Expr, e : Expr );
	EFor( v : String, it : Expr, e : Expr );
	EBreak;
	EContinue;
	EFunction( args : Array<{ name : String, t : Null<CType> }>, e : Expr, ?name : String, ?ret : CType );
	EReturn( ?e : Expr );
	EArray( e : Expr, index : Expr );
	EArrayDecl( e : Array<Expr> );
	ENew( cl : String, params : Array<Expr> );
	EThrow( e : Expr );
	ETry( e : Expr, v : String, t : Null<CType>, ecatch : Expr );
	EObject( fl : Array<{ name : String, e : Expr }> );
	ETernary( cond : Expr, e1 : Expr, e2 : Expr );
}

enum CType {
	CTPath( path : Array<String>, ?params : Array<CType> );
	CTFun( args : Array<CType>, ret : CType );
	CTAnon( fields : Array<{ name : String, t : CType }> );
	CTParent( t : CType );
}

class Error {
	public var e : ErrorDef;
	#if hscriptPos
	public var file : String;
	public var pmin : Int;
	public var pmax : Int;
	#end
	public function new(e) {
		this.e = e;
	}
	public function toString() {
		return Std.string(e) #if hscriptPos + " in " + file + " at char " + pmin + " to " + pmax #end;
	}
	static public inline function InExpr(ed:ErrorDef, ?expr:Expr) {
		var e = new Error(ed);
		#if hscriptPos
		if (expr!=null) {
			e.pmin = expr.pmin;
			e.pmax = expr.pmax;
			e.file = expr.file;
		}
		#end
		return e;
	}
}

enum ErrorDef {
	EInvalidChar( c : Int );
	EUnexpected( s : String );
	EUnterminatedString;
	EUnterminatedComment;
	EUnknownVariable( v : String );
	EInvalidIterator( v : String );
	EInvalidOp( op : String );
	EInvalidStmt( stmt : String );
	EInvalidAccess( f : String );
	EUnmatchedParameters( expect : Int, actual: Int );
}
