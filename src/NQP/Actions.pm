class NQP::Actions is HLL::Actions;

our @BLOCK;

INIT {
    our @BLOCK := Q:PIR { %r = new ['ResizablePMCArray'] };
}

sub xblock_immediate($xblock) {
    $xblock[1] := block_immediate($xblock[1]);
    $xblock;
}

sub block_immediate($block) {
    $block.blocktype('immediate');
    unless $block.symtable() || $block.handlers() {
        my $stmts := PAST::Stmts.new( :node($block) );
        for $block.list { $stmts.push($_); }
        $block := $stmts;
    }
    $block;
}

sub sigiltype($sigil) {
    $sigil eq '%'
    ?? 'Hash'
    !! ($sigil eq '@' ?? 'ResizablePMCArray' !! 'Undef');
}

method TOP($/) { make $<comp_unit>.ast; }

method deflongname($/) {
    make $<sym> ?? ~$<identifier> ~ ':sym<' ~ ~$<sym>[0] ~ '>' !! ~$/;
}

method comp_unit($/) {
    my $past := $<statementlist>.ast;
    my $BLOCK := @BLOCK.shift;
    $BLOCK.push($past);
    $BLOCK.node($/);
    make $BLOCK;
}

method statementlist($/) {
    my $past := PAST::Stmts.new( :node($/) );
    if $<statement> {
        for $<statement> {
            my $ast := $_.ast;
            if $ast.isa(PAST::Block) && !$ast.blocktype {
                $ast := block_immediate($ast);
            }
            $past.push( $ast );
        }
    }
    make $past;
}

method statement($/, $key?) {
    my $past;
    if $<EXPR> {
        my $mc := $<statement_mod_cond>[0];
        my $ml := $<statement_mod_loop>[0];
        if $mc {
            $past := PAST::Op.new($mc<cond>.ast, $<EXPR>.ast, :pasttype(~$mc<sym>), :node($/) );
            if $ml {
                $past := PAST::Op.new($ml<cond>.ast, $past, :pasttype(~$ml<sym>), :node($/) );
            }
        } elsif $ml {
            $past := PAST::Op.new($ml<cond>.ast, $<EXPR>.ast, :pasttype(~$ml<sym>), :node($/) );
        } else {
            $past := $<EXPR>.ast;
        }
    }
    elsif $<statement_control> { $past := $<statement_control>.ast; }
    else { $past := 0; }
    make $past;
}

method xblock($/) {
    make PAST::Op.new( $<EXPR>.ast, $<pblock>.ast, :pasttype('if'), :node($/) );
}

method pblock($/) {
    make $<blockoid>.ast;
}

method block($/) {
    make $<blockoid>.ast;
}

method blockoid($/) {
    my $past := $<statementlist>.ast;
    my $BLOCK := @BLOCK.shift;
    $BLOCK.push($past);
    $BLOCK.node($/);
    make $BLOCK;
}

method newpad($/) {
    our @BLOCK;
    @BLOCK.unshift( PAST::Block.new( PAST::Stmts.new() ) );
}

## Statement control

method statement_control:sym<if>($/) {
    my $count := +$<xblock> - 1;
    my $past := xblock_immediate( $<xblock>[$count].ast );
    if $<else> {
        $past.push( block_immediate( $<else>[0].ast ) );
    }
    # build if/then/elsif structure
    while $count > 0 {
        $count--;
        my $else := $past;
        $past := xblock_immediate( $<xblock>[$count].ast );
        $past.push($else);
    }
    make $past;
}

method statement_control:sym<unless>($/) {
    my $past := xblock_immediate( $<xblock>.ast );
    $past.pasttype('unless');
    make $past;
}

method statement_control:sym<while>($/) {
    my $past := xblock_immediate( $<xblock>.ast );
    $past.pasttype(~$<sym>);
    make $past;
}

method statement_control:sym<repeat>($/) {
    my $pasttype := 'repeat_' ~ ~$<wu>;
    my $past;
    if $<xblock> {
        $past := xblock_immediate( $<xblock>.ast );
        $past.pasttype($pasttype);
    }
    else {
        $past := PAST::Op.new( $<EXPR>.ast, block_immediate( $<pblock>.ast ),
                               :pasttype($pasttype), :node($/) );
    }
    make $past;
}

method statement_control:sym<for>($/) {
    my $past := $<xblock>.ast;
    $past.pasttype('for');
    my $block := $past[1];
    unless $block.arity {
        $block[0].push( PAST::Var.new( :name('$_'), :scope('parameter') ) );
        $block.symbol('$_', :scope('lexical') );
        $block.arity(1);
    }
    $block.blocktype('immediate');
    make $past;
}

method statement_control:sym<return>($/) {
    make PAST::Op.new( $<EXPR>.ast, :pasttype('return'), :node($/) );
}

method statement_control:sym<CATCH>($/) {
    my $block := $<block>.ast;
    push_block_handler($/, $block);
    @BLOCK[0].handlers()[0].handle_types_except('CONTROL');
    make PAST::Stmts.new(:node($/));
}

method statement_control:sym<CONTROL>($/) {
    my $block := $<block>.ast;
    push_block_handler($/, $block);
    @BLOCK[0].handlers()[0].handle_types('CONTROL');
    make PAST::Stmts.new(:node($/));
}

sub push_block_handler($/, $block) {
    unless @BLOCK[0].handlers() {
        @BLOCK[0].handlers([]);
    }
    unless $block.arity {
        $block.unshift(
            PAST::Op.new( :pasttype('bind'),
                PAST::Var.new( :scope('lexical'), :name('$!'), :isdecl(1) ),
                PAST::Var.new( :scope('lexical'), :name('$_')),
            ),
        );
        $block.unshift( PAST::Var.new( :name('$_'), :scope('parameter') ) );
        $block.symbol('$_', :scope('lexical') );
        $block.symbol('$!', :scope('lexical') );
        $block.arity(1);
    }
    $block.blocktype('declaration');
    @BLOCK[0].handlers.unshift(
        PAST::Control.new(
            :node($/),
            PAST::Stmts.new(
                PAST::Op.new( :pasttype('call'),
                    $block,
                    PAST::Var.new( :scope('register'), :name('exception')),
                ),
                PAST::Op.new( :pasttype('bind'),
                    PAST::Var.new( :scope('keyed'),
                        PAST::Var.new( :scope('register'), :name('exception')),
                        'handled'
                    ),
                    1
                )
            ),
        )
    );
}

method statement_prefix:sym<INIT>($/) {
    @BLOCK[0].loadinit.push($<blorst>.ast);
    make PAST::Stmts.new(:node($/));
}

method statement_prefix:sym<try>($/) {
    my $past := $<blorst>.ast;
    if $past.WHAT ne 'PAST::Block()' {
        $past := PAST::Block.new($past, :blocktype('immediate'), :node($/));
    }
    unless $past.handlers() {
        $past.handlers([PAST::Control.new(
                :handle_types_except('CONTROL'),
                PAST::Stmts.new(
                    PAST::Op.new( :pasttype('bind'),
                        PAST::Var.new( :scope('keyed'),
                            PAST::Var.new( :scope('register'), :name('exception')),
                            'handled'
                        ),
                        1
                    )
                )
            )]
        );
    }
    make $past;
}

method blorst($/) {
    make $<block>
         ?? block_immediate($<block>.ast)
         !! $<statement>.ast;
}

# Statement modifiers

method statement_mod_cond:sym<if>($/)     { make $<cond>.ast; }
method statement_mod_cond:sym<unless>($/) { make $<cond>.ast; }

method statement_mod_loop:sym<while>($/)  { make $<cond>.ast; }
method statement_mod_loop:sym<until>($/)  { make $<cond>.ast; }

## Terms

method term:sym<colonpair>($/)          { make $<colonpair>.ast; }
method term:sym<variable>($/)           { make $<variable>.ast; }
method term:sym<package_declarator>($/) { make $<package_declarator>.ast; }
method term:sym<scope_declarator>($/)   { make $<scope_declarator>.ast; }
method term:sym<routine_declarator>($/) { make $<routine_declarator>.ast; }
method term:sym<regex_declarator>($/)   { make $<regex_declarator>.ast; }
method term:sym<statement_prefix>($/)   { make $<statement_prefix>.ast; }
method term:sym<lambda>($/)             { make $<pblock>.ast; }

method colonpair($/) {
    my $past := $<circumfix>
                ?? $<circumfix>[0].ast
                !! PAST::Val.new( :value( !$<not> ) );
    $past.named( ~$<identifier> );
    make $past;
}

method variable($/) {
    my $past;
    if $<postcircumfix> {
        $past := $<postcircumfix>.ast;
        $past.unshift( PAST::Var.new( :name('$/') ) );
    }
    else {
        my @name := NQP::Compiler.parse_name(~$/);
        $past := PAST::Var.new( :name(~@name.pop) );
        if (@name) {
            if @name[0] eq 'GLOBAL' { @name.shift; }
            $past.namespace(@name);
            $past.scope('package');
            $past.viviself( sigiltype( $<sigil> ) );
            $past.lvalue(1);
        }
        if $<twigil>[0] eq '*' {
            $past.scope('contextual');
            $past.viviself( 
                PAST::Var.new( 
                    :scope('package'), :namespace(''), 
                    :name( ~$<sigil> ~ $<desigilname> ),
                    :viviself( 
                        PAST::Op.new( 'Contextual ' ~ ~$/ ~ ' not found',
                                      :pirop('die') )
                    )
                )
            );
        }
        elsif $<twigil>[0] eq '!' {
            $past.push(PAST::Var.new( :name('self') ));
            $past.scope('attribute');
            $past.viviself( sigiltype( $<sigil> ) );
        }
    }
    make $past;
}

method package_declarator:sym<module>($/) { make $<package_def>.ast; }
method package_declarator:sym<class>($/) {
    my $past := $<package_def>.ast;
    my $classinit :=
        PAST::Op.new(
            PAST::Op.new(
                :inline( '    %r = get_root_global ["parrot"], "P6metaclass"')
            ),
            ~$<package_def><name>,
            :name('new_class'),
            :pasttype('callmethod')
        );
    my $parent := ~$<package_def><parent>[0]
                  || ($<sym> eq 'grammar' ?? 'Regex::Cursor' !! '');
    if $parent {
        $classinit.push( PAST::Val.new( :value($parent), :named('parent') ) );
    }
    if $past<attributes> {
        $classinit.push( $past<attributes> );
    }
    @BLOCK[0].loadinit.push($classinit);
    make $past;
}

method package_def($/) {
    my $past := $<block> ?? $<block>.ast !! $<comp_unit>.ast;
    $past.namespace( $<name><identifier> );
    $past.blocktype('immediate');
    make $past;
}

method scope_declarator:sym<my>($/)  { make $<scoped>.ast; }
method scope_declarator:sym<our>($/) { make $<scoped>.ast; }
method scope_declarator:sym<has>($/) { make $<scoped>.ast; }

method scoped($/) {
    make $<routine_declarator>
         ?? $<routine_declarator>.ast
         !! $<variable_declarator>.ast;
}

method variable_declarator($/) {
    my $past := $<variable>.ast;
    my $sigil := $<variable><sigil>;
    my $name := $past.name;
    my $BLOCK := @BLOCK[0];
    if $BLOCK.symbol($name) {
        $/.CURSOR.panic("Redeclaration of symbol ", $name);
    }
    if $*SCOPE eq 'has' {
        $BLOCK.symbol($name, :scope('attribute') );
        unless $BLOCK<attributes> {
            $BLOCK<attributes> :=
                PAST::Op.new( :pasttype('list'), :named('attr') );
        }
        $BLOCK<attributes>.push( $name );
        $past := PAST::Stmts.new();
    }
    else {
        my $scope := $*SCOPE eq 'our' ?? 'package' !! 'lexical';
        my $decl := PAST::Var.new( :name($name), :scope($scope), :isdecl(1),
                                   :lvalue(1), :viviself( sigiltype($sigil) ),
                                   :node($/) );
        $BLOCK.symbol($name, :scope($scope) );
        $BLOCK[0].push($decl);
    }
    make $past;
}

method routine_declarator:sym<sub>($/) { make $<routine_def>.ast; }
method routine_declarator:sym<method>($/) { make $<method_def>.ast; }

method routine_def($/) {
    my $past := $<blockoid>.ast;
    $past.blocktype('declaration');
    $past.control('return_pir');
    if $<deflongname> {
        my $name := ~$<deflongname>[0].ast;
        $past.name($name);
        if $*SCOPE ne 'our' {
            @BLOCK[0][0].push(PAST::Var.new( :name($name), :isdecl(1),
                                  :viviself($past), :scope('lexical') ) );
            @BLOCK[0].symbol($name, :scope('lexical') );
            $past := PAST::Var.new( :name($name) );
        }
    }
    make $past;
}


method method_def($/) {
    my $past := $<blockoid>.ast;
    $past.blocktype('method');
    $past.control('return_pir');
    $past[0].unshift( PAST::Op.new( :inline('    .lex "self", self') ) );
    $past.symbol('self', :scope('lexical') );
    if $<deflongname> {
        my $name := ~$<deflongname>[0].ast;
        $past.name($name);
    }
    make $past;
}


method signature($/) {
    my $BLOCKINIT := @BLOCK[0][0];
    for $<parameter> { $BLOCKINIT.push($_.ast); }
}

method parameter($/) {
    my $quant := $<quant>;
    my $past;
    if $<named_param> {
        $past := $<named_param>.ast;
        if $quant ne '!' {
            $past.viviself( sigiltype($<named_param><param_var><sigil>) );
        }
    }
    else {
        $past := $<param_var>.ast;
        if $quant eq '*' {
            $past.slurpy(1);
            $past.named( $<param_var><sigil> eq '%' );
        }
        elsif $quant eq '?' {
            $past.viviself( sigiltype($<param_var><sigil>) );
        }
    }
    if $<default_value> {
        if $quant eq '*' {
            $/.CURSOR.panic("Can't put default on slurpy parameter");
        }
        if $quant eq '!' {
            $/.CURSOR.panic("Can't put default on required parameter");
        }
        $past.viviself( $<default_value>[0]<EXPR>.ast );
    }
    unless $past.viviself { @BLOCK[0].arity( +@BLOCK[0].arity + 1 ); }
    make $past;
}

method param_var($/) {
    my $name := ~$/;
    my $past :=  PAST::Var.new( :name($name), :scope('parameter'),
                                :isdecl(1), :node($/) );
    @BLOCK[0].symbol($name, :scope('lexical') );
    make $past;
}

method named_param($/) {
    my $past := $<param_var>.ast;
    $past.named( ~$<param_var><name> );
    make $past;
}

method regex_declarator($/, $key?) {
    my @MODIFIERS := Q:PIR {
        %r = get_hll_global ['Regex';'P6Regex';'Actions'], '@MODIFIERS'
    };
    my $name := ~$<deflongname>.ast;
    my $past;
    if $key eq 'open' {
        my %h;
        if $<sym> eq 'token' { %h<r> := 1; }
        if $<sym> eq 'rule'  { %h<r> := 1;  %h<s> := 1; }
        @MODIFIERS.unshift(%h);
        Q:PIR {
            $P0 = find_lex '$name'
            set_hll_global ['Regex';'P6Regex';'Actions'], '$REGEXNAME', $P0
        };
        @BLOCK[0].symbol('$¢', :scope('lexical'));
        @BLOCK[0].symbol('$/', :scope('lexical'));
        return 0;
    }
    elsif $<proto> {
        $past :=
            PAST::Stmts.new(
                PAST::Block.new( :name($name),
                    PAST::Op.new(
                        PAST::Var.new( :name('self'), :scope('register') ),
                        $name,
                        :name('!protoregex'),
                        :pasttype('callmethod')
                    ),
                    :blocktype('method'),
                    :lexical(0),
                    :node($/)
                ),
                PAST::Block.new( :name('!PREFIX__' ~ $name),
                    PAST::Op.new(
                        PAST::Var.new( :name('self'), :scope('register') ),
                        $name,
                        :name('!PREFIX__!protoregex'),
                        :pasttype('callmethod')
                    ),
                    :blocktype('method'),
                    :lexical(0),
                    :node($/)
                )
            );
    }
    else {
        $past := 
             Regex::P6Regex::Actions::buildsub($<p6regex>.ast, @BLOCK.shift);
        $past.name($name);
        @MODIFIERS.shift;
    }
    make $past;
}


method dotty($/) {
    my $past := $<args> ?? $<args>[0].ast !! PAST::Op.new( :node($/) );
    $past.name( $<quote> ?? $<quote>.ast !! ~$<longname> );
    $past.pasttype('callmethod');
    make $past;
}

## Terms

method term:sym<self>($/) {
    make PAST::Var.new( :name('self') );
}

method term:sym<identifier>($/) {
    my $past := $<args>.ast;
    $past.name(~$<identifier>);
    make $past;
}

method term:sym<name>($/) {
    my @ns := pir::clone__PP($<name><identifier>);
    my $name := @ns.pop;
    @ns.shift if @ns && @ns[0] eq 'GLOBAL';
    my $var :=
        PAST::Var.new( :name(~$name), :namespace(@ns), :scope('package') );
    my $past := $var;
    if $<args> {
        $past := $<args>[0].ast;
        $past.unshift($var);
    }
    make $past;
}

method term:sym<pir::op>($/) {
    my $past := $<args> ?? $<args>[0].ast !! PAST::Op.new( :node($/) );
    my $pirop := ~$<op>;
    $pirop := Q:PIR {
        $P0 = find_lex '$pirop'
        $S0 = $P0
        $P0 = split '__', $S0
        $S0 = join ' ', $P0
        %r = box $S0
    };
    $past.pirop($pirop);
    $past.pasttype('pirop');
    make $past;
}

method args($/) { make $<arglist>.ast; }

method arglist($/) {
    my $past := PAST::Op.new( :pasttype('call'), :node($/) );
    if $<EXPR> {
        my $expr := $<EXPR>.ast;
        if $expr.name eq '&infix:<,>' && !$expr.named {
            for $expr.list { $past.push($_); }
        }
        else { $past.push($expr); }
    }
    my $i := 0;
    my $n := +$past.list;
    while $i < $n {
        if $past[$i].name eq '&prefix:<|>' {
            $past[$i] := $past[$i][0];
            $past[$i].flat(1);
        }
        $i++;
    }
    make $past;
}


method term:sym<value>($/) { make $<value>.ast; }

method circumfix:sym<( )>($/) {
    make $<EXPR>
         ?? $<EXPR>[0].ast
         !! PAST::Op.new( :pasttype('list'), :node($/) );
}

method circumfix:sym<[ ]>($/) {
    my $past;
    if $<EXPR> {
        $past := $<EXPR>[0].ast;
        if $past.name ne '&infix:<,>' {
            $past := PAST::Op.new( $past, :pasttype('list') );
        }
    }
    else {
        $past := PAST::Op.new( :pasttype('list') );
    }
    $past.name('&circumfix:<[ ]>');
    make $past;
}

method circumfix:sym<ang>($/) { make $<quote_EXPR>.ast; }

method circumfix:sym<{ }>($/) {
    make +$<pblock><blockoid><statementlist><statement> > 0
         ?? $<pblock>.ast
         !! PAST::Op.new( :inline('    %r = new ["Hash"]'), :node($/) );
}

method circumfix:sym<sigil>($/) {
    my $name := ~$<sigil> eq '@' ?? 'list' !!
                ~$<sigil> eq '%' ?? 'hash' !!
                                    'item';
    make PAST::Op.new( :pasttype('callmethod'), :name($name), $<semilist>.ast );
}

method semilist($/) { make $<statement>.ast }

method postcircumfix:sym<[ ]>($/) {
    make PAST::Var.new( $<EXPR>.ast , :scope('keyed_int'),
                        :viviself('Undef'),
                        :vivibase('ResizablePMCArray') );
}

method postcircumfix:sym<{ }>($/) {
    make PAST::Var.new( $<EXPR>.ast , :scope('keyed'),
                        :viviself('Undef'),
                        :vivibase('Hash') );
}

method postcircumfix:sym<ang>($/) {
    make PAST::Var.new( $<quote_EXPR>.ast, :scope('keyed'),
                        :viviself('Undef'),
                        :vivibase('Hash') );
}

method postcircumfix:sym<( )>($/) {
    make $<arglist>.ast;
}

method value($/) {
    make $<quote> ?? $<quote>.ast !! $<number>.ast;
}

method number($/) {
    my $value := $<dec_number> ?? $<dec_number>.ast !! $<integer>.ast;
    if ~$<sign> eq '-' { $value := -$value; }
    make PAST::Val.new( :value($value) );
}

method quote:sym<apos>($/) { make $<quote_EXPR>.ast; }
method quote:sym<dblq>($/) { make $<quote_EXPR>.ast; }
method quote:sym<qq>($/)   { make $<quote_EXPR>.ast; }
method quote:sym<q>($/)    { make $<quote_EXPR>.ast; }
method quote:sym<Q>($/)    { make $<quote_EXPR>.ast; }
method quote:sym<Q:PIR>($/) {
    make PAST::Op.new( :inline( $<quote_EXPR>.ast.value ),
                       :pasttype('inline'),
                       :node($/) );
}

method quote_escape:sym<$>($/) { make $<variable>.ast; }
method quote_escape:sym<{ }>($/) {
    make PAST::Op.new(
        :pirop('set S*'), block_immediate($<block>.ast), :node($/)
    );
}

## Operators

method postfix:sym<.>($/) { make $<dotty>.ast; }

method postfix:sym<++>($/) {
    make PAST::Op.new( :name('postfix:<++>'),
                       :inline('    clone %r, %0', '    inc %0'),
                       :pasttype('inline') );
}

method postfix:sym<-->($/) {
    make PAST::Op.new( :name('postfix:<-->'),
                       :inline('    clone %r, %0', '    dec %0'),
                       :pasttype('inline') );
}

method prefix:sym<make>($/) {
    make PAST::Op.new(
             PAST::Var.new( :name('$/'), :scope('contextual') ),
             :pasttype('callmethod'),
             :name('!make'),
             :node($/)
    );
}


class NQP::RegexActions is Regex::P6Regex::Actions {

    method metachar:sym<:my>($/) {
        my $past := $<statement>.ast;
        make PAST::Regex.new( $past, :pasttype('pastnode') );
    }

    method metachar:sym<{ }>($/) { make $<codeblock>.ast; }

    method assertion:sym<{ }>($/) { make $<codeblock>.ast; }

    method codeblock($/) {
        my $block := $<block>.ast;
        $block.blocktype('immediate');
        my $past :=
            PAST::Regex.new(
                PAST::Stmts.new(
                    PAST::Op.new(
                        PAST::Var.new( :name('$/') ),
                        PAST::Op.new(
                            PAST::Var.new( :name('$¢') ),
                            :name('MATCH'),
                            :pasttype('callmethod')
                        ),
                        :pasttype('bind')
                    ),
                    $block
                ),
                :pasttype('pastnode')
            );
        make $past;
    }
}
