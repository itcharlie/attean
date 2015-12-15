#!/usr/bin/env perl

use v5.14;
use autodie;
use utf8;
use Test::More;
use Test::Exception;
use Digest::SHA qw(sha1_hex);
use AtteanX::SPARQL::Constants;

use Attean;
use Attean::RDF;

subtest 'expected tokens: empty BGP tokens' => sub {
	my $bgp	= Attean::Algebra::BGP->new(triples => []);
	my $i	= $bgp->sparql_tokens;
	does_ok($i, 'Attean::API::Iterator');
	expect_token_stream($i, []);
};

subtest 'expected tokens: 1-triple BGP tokens' => sub {
	my $t	= triple(iri('s'), iri('p'), literal('1'));
	my $bgp	= Attean::Algebra::BGP->new(triples => [$t]);
	my $i	= $bgp->sparql_tokens;
	does_ok($i, 'Attean::API::Iterator');
	expect_token_stream($i, [IRI, IRI, STRING1D, DOT]);
};

subtest 'expected tokens: 2-BGP join tokens' => sub {
	my $t	= triple(variable('s'), iri('p'), literal('1'));
	my $bgp	= Attean::Algebra::BGP->new(triples => [$t]);
	my $join	= Attean::Algebra::Join->new( children => [$bgp, $bgp] );
	my $i	= $join->sparql_tokens;
	does_ok($i, 'Attean::API::Iterator');
	
	# { ?v <p> "1" . ?v <p> "1" . }
	expect_token_stream($i, [LBRACE, VAR, IRI, STRING1D, DOT, VAR, IRI, STRING1D, DOT, RBRACE]);
};

subtest 'expected tokens: distinct/bgp' => sub {
	my $t	= triple(iri('s'), iri('p'), literal('1'));
	my $bgp	= Attean::Algebra::BGP->new(triples => [$t]);
	my $dist	= Attean::Algebra::Distinct->new( children => [$bgp] );
	my $i	= $dist->sparql_tokens;
	does_ok($i, 'Attean::API::Iterator');
	
	# SELECT DISTINCT * WHERE { <s> <p> "1" }
	expect_token_stream($i, [KEYWORD, KEYWORD, STAR, KEYWORD, LBRACE, IRI, IRI, STRING1D, DOT, RBRACE]);
};

subtest 'expected tokens: reduced/bgp' => sub {
	my $t	= triple(iri('s'), iri('p'), literal('1'));
	my $bgp	= Attean::Algebra::BGP->new(triples => [$t]);
	my $dist	= Attean::Algebra::Reduced->new( children => [$bgp] );
	my $i	= $dist->sparql_tokens;
	does_ok($i, 'Attean::API::Iterator');
	
	# SELECT REDUCED * WHERE { <s> <p> "1" }
	expect_token_stream($i, [KEYWORD, KEYWORD, STAR, KEYWORD, LBRACE, IRI, IRI, STRING1D, DOT, RBRACE]);
};

subtest 'expected tokens: bgp/limit' => sub {
	my $t	= triple(iri('s'), iri('p'), literal('1'));
	my $bgp	= Attean::Algebra::BGP->new(triples => [$t]);
	my $s	= Attean::Algebra::Slice->new( children => [$bgp], limit => 5 );
	my $i	= $s->sparql_tokens;
	does_ok($i, 'Attean::API::Iterator');
	
	# SELECT * WHERE { <s> <p> "1" } LIMIT 5
	expect_token_stream($i, [KEYWORD, STAR, KEYWORD, LBRACE, IRI, IRI, STRING1D, DOT, RBRACE, KEYWORD, INTEGER]);
};

subtest 'expected tokens: bgp/slice' => sub {
	my $t	= triple(iri('s'), iri('p'), literal('1'));
	my $bgp	= Attean::Algebra::BGP->new(triples => [$t]);
	my $s	= Attean::Algebra::Slice->new( children => [$bgp], limit => 5, offset => 5 );
	my $i	= $s->sparql_tokens;
	does_ok($i, 'Attean::API::Iterator');
	
	# SELECT * WHERE { <s> <p> "1" } LIMIT 5 OFFSET 5
	expect_token_stream($i, [KEYWORD, STAR, KEYWORD, LBRACE, IRI, IRI, STRING1D, DOT, RBRACE, KEYWORD, INTEGER, KEYWORD, INTEGER]);
};

subtest 'expected tokens: distinct/bgp/slice' => sub {
	my $t		= triple(iri('s'), iri('p'), literal('1'));
	my $bgp		= Attean::Algebra::BGP->new(triples => [$t]);
	my $dist	= Attean::Algebra::Distinct->new( children => [$bgp] );
	my $s		= Attean::Algebra::Slice->new( children => [$dist], limit => 5, offset => 5 );
	my $i		= $s->sparql_tokens;
	does_ok($i, 'Attean::API::Iterator');
	
	# SELECT DISTINCT * WHERE { <s> <p> "1" } LIMIT 5 OFFSET 5
	expect_token_stream($i, [KEYWORD, KEYWORD, STAR, KEYWORD, LBRACE, IRI, IRI, STRING1D, DOT, RBRACE, KEYWORD, INTEGER, KEYWORD, INTEGER]);
};

subtest 'property paths' => sub {
	subtest 'expected tokens: predicate path' => sub {
		my $p1	= iri('p1');
		my $pp1	= Attean::Algebra::PredicatePath->new( predicate => $p1 );
		my $i		= $pp1->sparql_tokens;
		expect_token_stream($i, [IRI]);
	};
	
	subtest 'expected tokens: nps path' => sub {
		my $p1	= iri('p1');
		my $p2	= iri('p2');
		my $nps	= Attean::Algebra::NegatedPropertySet->new( predicates => [$p1, $p2] );
		my $i		= $nps->sparql_tokens;
		# !(<p1>|<p2>)
		expect_token_stream($i, [BANG, LPAREN, IRI, OR, IRI, RPAREN]);
	};
	
	subtest 'expected tokens: 1-IRI sequence path' => sub {
		my $p2	= iri('p2');
		my $pp2	= Attean::Algebra::PredicatePath->new( predicate => $p2 );
		my $seq	= Attean::Algebra::SequencePath->new( children => [$pp2] );
		my $i	= $seq->sparql_tokens;
		expect_token_stream($i, [IRI]);
	};
	
	subtest 'expected tokens: 2-IRI sequence path' => sub {
		my $p1	= iri('p1');
		my $p2	= iri('p2');
		my $pp1	= Attean::Algebra::PredicatePath->new( predicate => $p1 );
		my $pp2	= Attean::Algebra::PredicatePath->new( predicate => $p2 );
		my $seq	= Attean::Algebra::SequencePath->new( children => [$pp1, $pp2] );
		my $i	= $seq->sparql_tokens;
		expect_token_stream($i, [IRI, SLASH, IRI]);
	};
	
	subtest 'expected tokens: 1-IRI alternative path' => sub {
		my $p2	= iri('p2');
		my $pp2	= Attean::Algebra::PredicatePath->new( predicate => $p2 );
		my $alt	= Attean::Algebra::AlternativePath->new( children => [$pp2] );
		my $i	= $alt->sparql_tokens;
		expect_token_stream($i, [IRI]);
	};
	
	subtest 'expected tokens: 2-IRI alternative path' => sub {
		my $p1	= iri('p1');
		my $p2	= iri('p2');
		my $pp1	= Attean::Algebra::PredicatePath->new( predicate => $p1 );
		my $pp2	= Attean::Algebra::PredicatePath->new( predicate => $p2 );
		my $alt	= Attean::Algebra::AlternativePath->new( children => [$pp1, $pp2] );
		my $i	= $alt->sparql_tokens;
		# <p1>|<p2>
		expect_token_stream($i, [IRI, OR, IRI]);
	};
	
	subtest 'expected tokens: 1-IRI inverse path' => sub {
		my $p2	= iri('p2');
		my $pp2	= Attean::Algebra::PredicatePath->new( predicate => $p2 );
		my $inv	= Attean::Algebra::InversePath->new( children => [$pp2] );
		my $i	= $inv->sparql_tokens;
		# ^<p1>
		expect_token_stream($i, [HAT, IRI]);
	};
	
	subtest 'expected tokens: 2-IRI inverse path' => sub {
		my $p1	= iri('p1');
		my $p2	= iri('p2');
		my $pp1	= Attean::Algebra::PredicatePath->new( predicate => $p1 );
		my $pp2	= Attean::Algebra::PredicatePath->new( predicate => $p2 );
		my $seq	= Attean::Algebra::AlternativePath->new( children => [$pp1, $pp2] );
		my $inv	= Attean::Algebra::InversePath->new( children => [$seq] );
		my $i	= $inv->sparql_tokens;
		# ^(<p1>/<p2>)
		expect_token_stream($i, [HAT, LPAREN, IRI, OR, IRI, RPAREN]);
	};
	
	subtest 'expected tokens: zero or more 2-IRI inverse path' => sub {
		my $p1	= iri('p1');
		my $p2	= iri('p2');
		my $pp1	= Attean::Algebra::PredicatePath->new( predicate => $p1 );
		my $pp2	= Attean::Algebra::PredicatePath->new( predicate => $p2 );
		my $seq	= Attean::Algebra::AlternativePath->new( children => [$pp1, $pp2] );
		my $inv	= Attean::Algebra::InversePath->new( children => [$seq] );
		my $zom	= Attean::Algebra::ZeroOrMorePath->new( children => [$inv] );
		my $i	= $zom->sparql_tokens;
		# (^(<p1>/<p2>))*
		expect_token_stream($i, [LPAREN, HAT, LPAREN, IRI, OR, IRI, RPAREN, RPAREN, STAR]);
	};
	
	subtest 'expected tokens: one or more 2-IRI inverse path' => sub {
		my $p1	= iri('p1');
		my $p2	= iri('p2');
		my $pp1	= Attean::Algebra::PredicatePath->new( predicate => $p1 );
		my $pp2	= Attean::Algebra::PredicatePath->new( predicate => $p2 );
		my $seq	= Attean::Algebra::AlternativePath->new( children => [$pp1, $pp2] );
		my $inv	= Attean::Algebra::InversePath->new( children => [$seq] );
		my $oom	= Attean::Algebra::OneOrMorePath->new( children => [$inv] );
		my $i	= $oom->sparql_tokens;
		# (^(<p1>/<p2>))+
		expect_token_stream($i, [LPAREN, HAT, LPAREN, IRI, OR, IRI, RPAREN, RPAREN, PLUS]);
	};
	
	subtest 'expected tokens: zero or one 2-IRI inverse path' => sub {
		my $p1	= iri('p1');
		my $p2	= iri('p2');
		my $pp1	= Attean::Algebra::PredicatePath->new( predicate => $p1 );
		my $pp2	= Attean::Algebra::PredicatePath->new( predicate => $p2 );
		my $seq	= Attean::Algebra::AlternativePath->new( children => [$pp1, $pp2] );
		my $inv	= Attean::Algebra::InversePath->new( children => [$seq] );
		my $zoo	= Attean::Algebra::ZeroOrOnePath->new( children => [$inv] );
		my $i	= $zoo->sparql_tokens;
		# (^(<p1>/<p2>))+
		expect_token_stream($i, [LPAREN, HAT, LPAREN, IRI, OR, IRI, RPAREN, RPAREN, QUESTION]);
	};

	subtest 'expected tokens: 2-IRI sequence path triple' => sub {
		my $p1	= iri('p1');
		my $p2	= iri('p2');
		my $pp1	= Attean::Algebra::PredicatePath->new( predicate => $p1 );
		my $pp2	= Attean::Algebra::PredicatePath->new( predicate => $p2 );
		my $seq	= Attean::Algebra::SequencePath->new( children => [$pp1, $pp2] );
		my $t	= Attean::Algebra::Path->new( path => $seq, subject => iri('s'), object => iri('o') );
		my $i	= $t->sparql_tokens;
		expect_token_stream($i, [IRI, IRI, SLASH, IRI, IRI]);
	};
};

subtest 'expected tokens: union tokens' => sub {
	my $lhs	= Attean::Algebra::BGP->new(triples => [triple(iri('s'), iri('p'), literal('1'))]);
	my $rhs	= Attean::Algebra::BGP->new(triples => [triple(iri('s'), iri('p'), literal('2'))]);
	my $a	= Attean::Algebra::Union->new( children => [$lhs, $rhs] );
	my $i	= $a->sparql_tokens;
	does_ok($i, 'Attean::API::Iterator');
	expect_token_stream($i, [LBRACE, IRI, IRI, STRING1D, DOT, RBRACE, KEYWORD, LBRACE, IRI, IRI, STRING1D, DOT, RBRACE]);
};

subtest 'expected tokens: minus tokens' => sub {
	my $lhs	= Attean::Algebra::BGP->new(triples => [triple(variable('s'), iri('p'), literal('1'))]);
	my $rhs	= Attean::Algebra::BGP->new(triples => [triple(variable('s'), iri('p'), literal('2'))]);
	my $a	= Attean::Algebra::Minus->new( children => [$lhs, $rhs] );
	my $i	= $a->sparql_tokens;
	does_ok($i, 'Attean::API::Iterator');
	# { ?s <p> "1" . } MINUS { ?s <p> "1" . }
	expect_token_stream($i, [LBRACE, VAR, IRI, STRING1D, DOT, RBRACE, KEYWORD, LBRACE, VAR, IRI, STRING1D, DOT, RBRACE]);
};

subtest 'expected tokens: optional tokens' => sub {
	my $lhs	= Attean::Algebra::BGP->new(triples => [triple(variable('s'), iri('p'), literal('1'))]);
	my $rhs	= Attean::Algebra::BGP->new(triples => [triple(variable('s'), iri('p'), literal('2'))]);
	my $a	= Attean::Algebra::LeftJoin->new( children => [$lhs, $rhs] );
	my $i	= $a->sparql_tokens;
	does_ok($i, 'Attean::API::Iterator');
	# { ?s <p> "1" . } OPTIONAL { ?s <p> "1" . }
	expect_token_stream($i, [LBRACE, VAR, IRI, STRING1D, DOT, RBRACE, KEYWORD, LBRACE, VAR, IRI, STRING1D, DOT, RBRACE]);
};

TODO: {
local($TODO)	= 'LeftJoin with filter expression';
subtest 'expected tokens: optional+filter tokens' => sub {
	my $lhs	= Attean::Algebra::BGP->new(triples => [triple(variable('s'), iri('p'), literal('1'))]);
	my $rhs	= Attean::Algebra::BGP->new(triples => [triple(variable('s'), iri('p'), literal('2'))]);
	fail();
	my $a	= Attean::Algebra::LeftJoin->new( children => [$lhs, $rhs] );
	my $i	= $a->sparql_tokens;
	does_ok($i, 'Attean::API::Iterator');
	# { ?s <p> "1" . } OPTIONAL { ?s <p> "1" . FILTER(...) }
	expect_token_stream($i, [LBRACE, VAR, IRI, STRING1D, DOT, RBRACE, KEYWORD, LBRACE, VAR, IRI, STRING1D, DOT, RBRACE]);
};
}

subtest 'expected tokens: comparator tokens' => sub {
	my $bgp		= Attean::Algebra::BGP->new(triples => [triple(variable('s'), iri('p'), literal('1'))]);
	my $expr	= Attean::ValueExpression->new( value => variable('s') );
	my $cmp		= Attean::Algebra::Comparator->new(ascending => 0, expression => $expr);
	my $i		= $cmp->sparql_tokens;
	does_ok($i, 'Attean::API::Iterator');
	
	# DESC(?s)
	expect_token_stream($i, [KEYWORD, LPAREN, VAR, RPAREN]);
};

subtest 'expected tokens: comparator tokens' => sub {
	my $bgp		= Attean::Algebra::BGP->new(triples => [triple(variable('s'), iri('p'), literal('1'))]);
	my $expr	= Attean::ValueExpression->new( value => variable('s') );
	my $cmp		= Attean::Algebra::Comparator->new(ascending => 0, expression => $expr);
	my $a		= Attean::Algebra::OrderBy->new( children => [$bgp], comparators => [$cmp] );
	my $i		= $a->sparql_tokens;
	does_ok($i, 'Attean::API::Iterator');
	
	# SELECT * WHERE { ?s <p> "1" . } ORDER BY DESC(?s)
	expect_token_stream($i, [KEYWORD, STAR, KEYWORD, LBRACE, VAR, IRI, STRING1D, DOT, RBRACE, KEYWORD, KEYWORD, KEYWORD, LPAREN, VAR, RPAREN]);
};

subtest 'expected tokens: ASK tokens' => sub {
	my $bgp		= Attean::Algebra::BGP->new(triples => [triple(variable('s'), iri('p'), literal('1'))]);
	my $a		= Attean::Algebra::Ask->new( children => [$bgp] );
	my $i		= $a->sparql_tokens;
	does_ok($i, 'Attean::API::Iterator');
	
	# ASK { ?s <p> "1" . }
	expect_token_stream($i, [KEYWORD, LBRACE, VAR, IRI, STRING1D, DOT, RBRACE]);
};



# Attean::Algebra::Construct
# Attean::Algebra::Extend
# Attean::Algebra::Graph
# Attean::Algebra::Project
# Attean::Algebra::Sequence
# Attean::Algebra::Service
# Attean::Algebra::Table


done_testing();
exit;


{
	note('BGP canonicalization');
	my $b		= blank('person');
	my $rdf_type	= iri('http://www.w3.org/1999/02/22-rdf-syntax-ns#type');
	my $foaf_name	= iri('http://xmlns.com/foaf/0.1/name');
	my $foaf_knows	= iri('http://xmlns.com/foaf/0.1/knows');
	my $foaf_Person	= iri('http://xmlns.com/foaf/0.1/Person');
	my $bgp1	= Attean::Algebra::BGP->new( triples => [
		triplepattern($b, $rdf_type, $foaf_Person),
		triplepattern($b, $foaf_name, variable('name')),
		triplepattern($b, $foaf_knows, variable('knows')),
	] );
	my $bgp2	= Attean::Algebra::BGP->new( triples => [
		triplepattern(blank('s'), $foaf_knows, variable('person')),
		triplepattern(blank('s'), $rdf_type, $foaf_Person),
		triplepattern(blank('s'), $foaf_name, variable('myname')),
	] );

	my $hash1	= sha1_hex( join("\n", map { $_->tuples_string } (@{$bgp1->triples}) ) );
	my $hash2	= sha1_hex( join("\n", map { $_->tuples_string } (@{$bgp2->triples}) ) );
	isnt($hash1, $hash2, 'non-matching pre-canonicalized BGP hashes');
	
	my ($cbgp1, $m1)	= $bgp1->canonical_bgp_with_mapping;
	my ($cbgp2, $m2)	= $bgp2->canonical_bgp_with_mapping;
	
	my $chash1	= sha1_hex( join("\n", map { $_->tuples_string } (@{$cbgp1->triples}) ) );
	my $chash2	= sha1_hex( join("\n", map { $_->tuples_string } (@{$cbgp2->triples}) ) );
	is($chash1, $chash2, 'matching canonicalized BGP hashes' );
	
	is_deeply($m1, { '?name' => { 'prefix' => '?', 'id' => 'v003', 'type' => 'variable' }, '?knows' => { 'id' => 'v002', 'prefix' => '?', 'type' => 'variable' }, '_:person' => { 'id' => 'v001', 'prefix' => '_:', 'type' => 'blank' } }, 'BGP1 mapping');
	is_deeply($m2, { '?person' => { 'prefix' => '?', 'id' => 'v002', 'type' => 'variable' }, '_:s' => { 'prefix' => '_:', 'id' => 'v001', 'type' => 'blank' }, '?myname' => { 'type' => 'variable', 'id' => 'v003', 'prefix' => '?' } }, 'BGP2 mapping');
}

{
	my $t		= triple(variable('s'), iri('p'), variable('o'));
	my $bgp		= Attean::Algebra::BGP->new(triples => [$t]);
	my @groups	= Attean::ValueExpression->new( value => variable('s') );
	my @aggs	= Attean::AggregateExpression->new(
		distinct	=> 0,
		operator	=> 'SUM',
		children	=> [Attean::ValueExpression->new( value => variable('s') )],
		scalar_vars	=> {},
		variable	=> variable("sum"),
	);
	my $agg		= Attean::Algebra::Group->new(
		children => [$bgp],
		groupby => \@groups,
		aggregates => \@aggs,
	);
	my $s	= $agg->as_string;
	like($s, qr/Group { [?]s } aggregate { [?]sum ← SUM\([?]s\) }/, 'aggregate serialization');
}

{
	note('Aggregation');
	my $t		= triple(variable('s'), iri('p'), variable('o'));
	my $bgp		= Attean::Algebra::BGP->new(triples => [$t]);
	my @groups	= Attean::ValueExpression->new( value => variable('s') );
	my @aggs	= Attean::AggregateExpression->new(
		distinct	=> 0,
		operator	=> 'SUM',
		children	=> [Attean::ValueExpression->new( value => variable('s') )],
		scalar_vars	=> {},
		variable	=> variable("sum"),
	);
	my $agg		= Attean::Algebra::Group->new(
		children => [$bgp],
		groupby => \@groups,
		aggregates => \@aggs,
	);
	my $s	= $agg->as_string;
	like($s, qr/Group { [?]s } aggregate { [?]sum ← SUM\([?]s\) }/, 'aggregate serialization');
}

{
	note('Ranking');
	# RANKing example for 2 youngest students per school
	my $bgp		= Attean::Algebra::BGP->new(triples => [
		triple(variable('p'), iri('ex:name'), variable('name')),
		triple(variable('p'), iri('ex:school'), variable('school')),
		triple(variable('p'), iri('ex:age'), variable('age')),
	]);
	my @groups	= Attean::ValueExpression->new( value => variable('school') );
	my $r_agg	= Attean::AggregateExpression->new(
		distinct	=> 0,
		operator	=> 'RANK',
		children	=> [Attean::ValueExpression->new( value => variable('age') )],
		scalar_vars	=> {},
		variable	=> variable("rank"),
	);
	my $agg		= Attean::Algebra::Group->new(
		children => [$bgp],
		groupby => \@groups,
		aggregates => [$r_agg],
	);
	my $rank	= Attean::Algebra::Filter->new(
		children	=> [$agg],
		expression	=> Attean::BinaryExpression->new(
			children => [
				Attean::ValueExpression->new( value => variable('rank') ),
				Attean::ValueExpression->new( value => Attean::Literal->integer('2') ),
			],
			operator => '<='
		),
	);
	my $s	= $rank->as_string;
	like($s, qr/Group { [?]school } aggregate { [?]rank ← RANK\([?]age\) }/, 'ranking serialization');
}

done_testing();


sub does_ok {
    my ($class_or_obj, $does, $message) = @_;
    $message ||= "The object does $does";
    ok(eval { $class_or_obj->does($does) }, $message);
}

sub expect_token_stream {
	my $i		= shift;
	my $expect	= shift;
	while (my $t = $i->next) {
		my $type	= AtteanX::SPARQL::Constants::decrypt_constant($t->type);
		is_token_of_type($t, shift(@$expect));
	}
	is(scalar(@$expect), 0);
}

sub is_token_of_type {
	my $t			= shift;
	my $got			= $t->type;
	my $expect		= shift;
	if ($expect == A) {
		Carp::confess;
	}
	my $got_name	= AtteanX::SPARQL::Constants::decrypt_constant($got);
	my $expect_name	= AtteanX::SPARQL::Constants::decrypt_constant($expect);
	if ($got == $expect) {
		pass("Expected token type $got_name");
	} else {
		my $value	= $t->value;
		fail("Not expected token type (expected $expect_name, but got $got_name $value)");
	}
}
