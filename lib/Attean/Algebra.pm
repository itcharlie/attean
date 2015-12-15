use v5.14;
use warnings;

=head1 NAME

Attean::Algebra - Representation of SPARQL algebra operators

=head1 VERSION

This document describes Attean::Algebra version 0.009

=head1 SYNOPSIS

  use v5.14;
  use Attean;

=head1 DESCRIPTION

This is a utility package that defines all the Attean query algebra classes
in the Attean::Algebra namespace:

=over 4

=cut

use Attean::API::Query;

package Attean::Algebra::Sequence 0.009 {
	use AtteanX::SPARQL::Constants;
	use AtteanX::SPARQL::Token;
	use Moo;
	use namespace::clean;

	with 'Attean::API::UnionScopeVariables', 'Attean::API::Algebra', 'Attean::API::QueryTree';
	with 'Attean::API::SPARQLSerializable';

	sub algebra_as_string { return 'Sequence' }
	sub as_sparql {
		my $self	= shift;
		my %args	= @_;
		my $level	= $args{level} // 0;
		my $sp		= $args{indent} // '    ';
		my $indent	= $sp x $level;
		
		return join(";\n", map { $_->as_sparql( %args ) } @{ $self->children });
	}

	sub sparql_tokens {
		my $self	= shift;
		my $semi	= AtteanX::SPARQL::Token->fast_constructor( SEMICOLON, -1, -1, -1, -1, [';'] );

		my @tokens;
		foreach my $t (@{ $self->children }) {
			push(@tokens, $t->sparql_tokens->elements);
			push(@tokens, $semi);
		}
		pop(@tokens); # remove last SEMICOLON token
		return Attean::ListIterator->new( values => \@tokens, item_type => 'AtteanX::SPARQL::Token' );
	}
}

=item * L<Attean::Algebra::Join>

=cut

package Attean::Algebra::Join 0.009 {
	use AtteanX::SPARQL::Constants;
	use AtteanX::SPARQL::Token;
	use Moo;
	use namespace::clean;

	with 'Attean::API::UnionScopeVariables', 'Attean::API::Algebra', 'Attean::API::QueryTree';
	with 'Attean::API::SPARQLSerializable';

	sub algebra_as_string { return 'Join' }

	sub sparql_tokens {
		my $self	= shift;
		my $l	= AtteanX::SPARQL::Token->fast_constructor( LBRACE, -1, -1, -1, -1, ['{'] );
		my $r	= AtteanX::SPARQL::Token->fast_constructor( RBRACE, -1, -1, -1, -1, ['}'] );

		my @tokens;
		push(@tokens, $l);
		foreach my $t (@{ $self->children }) {
			push(@tokens, $t->sparql_tokens->elements);
		}
		push(@tokens, $r);
		return Attean::ListIterator->new( values => \@tokens, item_type => 'AtteanX::SPARQL::Token' );
	}
	
	sub as_sparql {
		my $self	= shift;
		my %args	= @_;
		my $level	= $args{level} // 0;
		my $sp		= $args{indent} // '    ';
		my $indent	= $sp x $level;
		
		return join('', map { $_->as_sparql( %args ) } @{ $self->children });
	}
}

=item * L<Attean::Algebra::LeftJoin>

=cut

package Attean::Algebra::LeftJoin 0.009 {
	use AtteanX::SPARQL::Constants;
	use AtteanX::SPARQL::Token;
	use Moo;
	use Types::Standard qw(ConsumerOf);
	use namespace::clean;

	with 'Attean::API::UnionScopeVariables', 'Attean::API::Algebra', 'Attean::API::BinaryQueryTree';
	with 'Attean::API::SPARQLSerializable';

	has 'expression' => (is => 'ro', isa => ConsumerOf['Attean::API::Expression'], required => 1, default => sub { Attean::ValueExpression->new( value => Attean::Literal->true ) });
	sub algebra_as_string {
		my $self	= shift;
		return sprintf('LeftJoin { %s }', $self->expression->as_string);
	}
	sub tree_attributes { return qw(expression) };
	sub as_sparql {
		my $self	= shift;
		my %args	= @_;
		my $level	= $args{level} // 0;
		my $sp		= $args{indent} // '    ';
		my $indent	= $sp x $level;
		my ($lhs, $rhs)	= @{ $self->children };
		
		my $s	= "${indent}{\n"
			. $lhs->as_sparql( %args, level => $level+1 )
			. "${indent}} OPTIONAL {\n"
			. $rhs->as_sparql( %args, level => $level+1 );
		
		my $e	= $self->expression->as_sparql( %args, level => $level+1 );
		if ($e ne 'true') {
			$s	.= "${indent}$e\n";
		}
		
		$s	.= "${indent}}\n";
		return $s;
	}

	sub sparql_tokens {
		my $self	= shift;
		my $opt	= AtteanX::SPARQL::Token->fast_constructor( KEYWORD, -1, -1, -1, -1, ['OPTIONAL'] );
		my $l	= AtteanX::SPARQL::Token->fast_constructor( LBRACE, -1, -1, -1, -1, ['{'] );
		my $r	= AtteanX::SPARQL::Token->fast_constructor( RBRACE, -1, -1, -1, -1, ['}'] );
		my ($lhs, $rhs)	= @{ $self->children };
		
		my @tokens;
		push(@tokens, $l);
		push(@tokens, $lhs->sparql_tokens->elements);
		push(@tokens, $r, $opt, $l);
		push(@tokens, $rhs->sparql_tokens->elements);
		push(@tokens, $r);
		return Attean::ListIterator->new( values => \@tokens, item_type => 'AtteanX::SPARQL::Token' );
	}
	
}

=item * L<Attean::Algebra::Filter>

=cut

package Attean::Algebra::Filter 0.009 {
	use Moo;
	use Types::Standard qw(ConsumerOf);
	with 'Attean::API::UnionScopeVariables', 'Attean::API::Algebra', 'Attean::API::UnaryQueryTree';
	has 'expression' => (is => 'ro', isa => ConsumerOf['Attean::API::Expression'], required => 1);
	sub algebra_as_string {
		my $self	= shift;
		return sprintf('Filter { %s }', $self->expression->as_string);
	}
	sub tree_attributes { return qw(expression) };
	sub as_sparql {
		my $self	= shift;
		my %args	= @_;
		my $level	= $args{level} // 0;
		my $sp		= $args{indent} // '    ';
		my $indent	= $sp x $level;
		my ($lhs, $rhs)	= @{ $self->children };
		
		my ($child)	= @{ $self->children };
		return $child->as_sparql( %args )
			. "${indent}FILTER(" . $self->expression->as_sparql . ")\n";
	}
}

=item * L<Attean::Algebra::Union>

=cut

package Attean::Algebra::Union 0.009 {
	use AtteanX::SPARQL::Constants;
	use AtteanX::SPARQL::Token;
	use Moo;
	use Types::Standard qw(ConsumerOf);
	use namespace::clean;

	with 'Attean::API::UnionScopeVariables', 'Attean::API::Algebra', 'Attean::API::BinaryQueryTree';
	with 'Attean::API::SPARQLSerializable';

	sub algebra_as_string { return 'Union' }
	sub as_sparql {
		my $self	= shift;
		my %args	= @_;
		my $level	= $args{level} // 0;
		my $sp		= $args{indent} // '    ';
		my $indent	= $sp x $level;
		my ($lhs, $rhs)	= @{ $self->children };
		
		return "${indent}{\n"
			. $lhs->as_sparql( %args, level => $level+1 )
			. "${indent}} UNION {\n"
			. $rhs->as_sparql( %args, level => $level+1 )
			. "${indent}}\n";
	}

	sub sparql_tokens {
		my $self	= shift;
		my $union	= AtteanX::SPARQL::Token->fast_constructor( KEYWORD, -1, -1, -1, -1, ['UNION'] );
		my $l		= AtteanX::SPARQL::Token->fast_constructor( LBRACE, -1, -1, -1, -1, ['{'] );
		my $r		= AtteanX::SPARQL::Token->fast_constructor( RBRACE, -1, -1, -1, -1, ['}'] );
		my ($lhs, $rhs)	= @{ $self->children };
		
		my @tokens;
		push(@tokens, $l);
		push(@tokens, $lhs->sparql_tokens->elements);
		push(@tokens, $r, $union, $l);
		push(@tokens, $rhs->sparql_tokens->elements);
		push(@tokens, $r);
		return Attean::ListIterator->new( values => \@tokens, item_type => 'AtteanX::SPARQL::Token' );
	}
}

=item * L<Attean::Algebra::Graph>

=cut

package Attean::Algebra::Graph 0.009 {
	use AtteanX::SPARQL::Constants;
	use AtteanX::SPARQL::Token;
	use Moo;
	use Types::Standard qw(ConsumerOf);
	use namespace::clean;

	with 'Attean::API::Algebra', 'Attean::API::UnaryQueryTree';
	with 'Attean::API::SPARQLSerializable';

	has 'graph' => (is => 'ro', isa => ConsumerOf['Attean::API::TermOrVariable'], required => 1);

	sub in_scope_variables {
		my $self	= shift;
		my $graph	= $self->graph;
		my ($child)	= @{ $self->children };
		my @vars	= $child->in_scope_variables;
		if ($graph->does('Attean::API::Variable')) {
			return Set::Scalar->new(@vars, $graph->value)->elements;
		} else {
			return @vars;
		}
	}
	sub algebra_as_string {
		my $self	= shift;
		return sprintf('Graph %s', $self->graph->as_string);
	}
	sub tree_attributes { return qw(graph) };
	sub as_sparql {
		my $self	= shift;
		my %args	= @_;
		my $level	= $args{level} // 0;
		my $sp		= $args{indent} // '    ';
		my $indent	= $sp x $level;
		
		my ($child)	= @{ $self->children };
		my $g		= $self->graph->as_sparql;
		return "${indent}GRAPH $g {\n"
			. $child->as_sparql( %args, level => $level+1 )
			. "${indent}}\n";
	}

	sub sparql_tokens {
		my $self	= shift;
		my $graph	= AtteanX::SPARQL::Token->fast_constructor( KEYWORD, -1, -1, -1, -1, ['GRAPH'] );
		my $l		= AtteanX::SPARQL::Token->fast_constructor( LBRACE, -1, -1, -1, -1, ['{'] );
		my $r		= AtteanX::SPARQL::Token->fast_constructor( RBRACE, -1, -1, -1, -1, ['}'] );
		my ($child)	= @{ $self->children };
		
		my @tokens;
		push(@tokens, $graph);
		push(@tokens, $self->graph->sparql_tokens->elements);
		push(@tokens, $l);
		push(@tokens, $child->sparql_tokens->elements);
		push(@tokens, $r);
		return Attean::ListIterator->new( values => \@tokens, item_type => 'AtteanX::SPARQL::Token' );
	}
}

=item * L<Attean::Algebra::Extend>

=cut

package Attean::Algebra::Extend 0.009 {
	use Moo;
	use Types::Standard qw(ConsumerOf);
	sub in_scope_variables {
		my $self	= shift;
		my ($child)	= @{ $self->children };
		my @vars	= $child->in_scope_variables;
		return Set::Scalar->new(@vars, $self->variable->value)->elements;
	}
	with 'Attean::API::Algebra', 'Attean::API::UnaryQueryTree';
	has 'variable' => (is => 'ro', isa => ConsumerOf['Attean::API::Variable'], required => 1);
	has 'expression' => (is => 'ro', isa => ConsumerOf['Attean::API::Expression'], required => 1);
	sub algebra_as_string {
		my $self	= shift;
		return sprintf('Extend { %s ← %s }', $self->variable->as_string, $self->expression->as_string);
	}
	sub tree_attributes { return qw(variable expression) };
	sub as_sparql {
		my $self	= shift;
		my %args	= @_;
		my %vmap	= %{ $args{ aggregate_variables } // {} };
		my $level	= $args{level} // 0;
		my $sp		= $args{indent} // '    ';
		my $indent	= $sp x $level;
		my ($lhs, $rhs)	= @{ $self->children };
		
		my $expr	= $self->expression;
		my $var		= $self->variable;
		if ($expr->isa('Attean::ValueExpression')) {
			$vmap{ $expr->value->value }	= $var->as_sparql;
		}
		my ($child)	= @{ $self->children };

		my %in_scope	= map { $_ => 1 } $child->in_scope_variables;
		my $sparql;
		if ($child->isa('Attean::Algebra::Group')) {
			$sparql	= "${indent}{\n";
			$sparql	.= $child->as_sparql( %args, level => $level+1, aggregate_variables => \%vmap );
			$sparql	.= "${indent}}\n";
		} else {
			$sparql	= $child->as_sparql( %args, aggregate_variables => \%vmap );
		}
		my $evar	= $expr->isa('Attean::ValueExpression') ? $expr->value->value : $expr->as_sparql;
		unless (exists $in_scope{$evar}) {
			$sparql	.= "${indent}BIND(" . $expr->as_sparql . " AS " . $var->as_sparql . ")\n";
		}
		return $sparql;
	}
}

=item * L<Attean::Algebra::Minus>

=cut

package Attean::Algebra::Minus 0.009 {
	use AtteanX::SPARQL::Constants;
	use AtteanX::SPARQL::Token;
	use Moo;
	use Types::Standard qw(ConsumerOf);
	use namespace::clean;

	with 'Attean::API::Algebra', 'Attean::API::BinaryQueryTree';
	with 'Attean::API::SPARQLSerializable';

	sub in_scope_variables {
		my $self	= shift;
		my ($child)	= @{ $self->children };
		return $child->in_scope_variables;
	}

	sub algebra_as_string { return 'Minus' }
	sub as_sparql {
		my $self	= shift;
		my %args	= @_;
		my $level	= $args{level} // 0;
		my $sp		= $args{indent} // '    ';
		my $indent	= $sp x $level;
		my ($lhs, $rhs)	= @{ $self->children };
		
		return "${indent}{\n"
			. $lhs->as_sparql( %args, level => $level+1 )
			. "${indent}} MINUS {\n"
			. $rhs->as_sparql( %args, level => $level+1 )
			. "${indent}}\n";
	}

	sub sparql_tokens {
		my $self	= shift;
		my $minus	= AtteanX::SPARQL::Token->fast_constructor( KEYWORD, -1, -1, -1, -1, ['MINUS'] );
		my $l		= AtteanX::SPARQL::Token->fast_constructor( LBRACE, -1, -1, -1, -1, ['{'] );
		my $r		= AtteanX::SPARQL::Token->fast_constructor( RBRACE, -1, -1, -1, -1, ['}'] );
		my ($lhs, $rhs)	= @{ $self->children };
		
		my @tokens;
		push(@tokens, $l);
		push(@tokens, $lhs->sparql_tokens->elements);
		push(@tokens, $r, $minus, $l);
		push(@tokens, $rhs->sparql_tokens->elements);
		push(@tokens, $r);
		return Attean::ListIterator->new( values => \@tokens, item_type => 'AtteanX::SPARQL::Token' );
	}
	
}

=item * L<Attean::Algebra::Distinct>

=cut

package Attean::Algebra::Distinct 0.009 {
	use Moo;
	use namespace::clean;

	with 'Attean::API::UnionScopeVariables', 'Attean::API::Algebra', 'Attean::API::UnaryQueryTree';
	with 'Attean::API::SPARQLQuerySerializable';

	sub algebra_as_string { return 'Distinct' }
	sub as_sparql {
		my $self	= shift;
		my %args	= @_;
		my $level	= $args{level} // 0;
		my $sp		= $args{indent} // '    ';
		my $indent	= $sp x $level;
		my ($child)	= @{ $self->children };
		
		if ($child->isa('Attean::Algebra::Project')) {
			return $child->as_sparql( %args, distinct => 1 );
		} else {
			return "${indent}SELECT DISTINCT * WHERE {\n"
				. $child->as_sparql( %args, level => $level+1 )
				. "${indent}}\n";
		}
	}
}

=item * L<Attean::Algebra::Reduced>

=cut

package Attean::Algebra::Reduced 0.009 {
	use Moo;
	use namespace::clean;

	with 'Attean::API::UnionScopeVariables', 'Attean::API::Algebra', 'Attean::API::UnaryQueryTree';
	with 'Attean::API::SPARQLQuerySerializable';

	sub algebra_as_string { return 'Reduced' }
	sub as_sparql {
		my $self	= shift;
		my %args	= @_;
		my $level	= $args{level} // 0;
		my $sp		= $args{indent} // '    ';
		my $indent	= $sp x $level;
		my ($child)	= @{ $self->children };
		
		if ($child->isa('Attean::Algebra::Project')) {
			return $child->as_sparql( %args, level => $level+1, reduced => 1 );
		} else {
			return "${indent}SELECT REDUCED * WHERE {\n"
				. $child->as_sparql( %args )
				. "${indent}}\n";
		}
	}
}

=item * L<Attean::Algebra::Slice>

=cut

package Attean::Algebra::Slice 0.009 {
	use Moo;
	use Types::Standard qw(Int);
	use namespace::clean;

	with 'Attean::API::UnionScopeVariables', 'Attean::API::Algebra', 'Attean::API::UnaryQueryTree';
	with 'Attean::API::SPARQLQuerySerializable';

	has 'limit' => (is => 'ro', isa => Int, default => -1);
	has 'offset' => (is => 'ro', isa => Int, default => 0);
	sub algebra_as_string {
		my $self	= shift;
		my @str	= ('Slice');
		push(@str, "Limit=" . $self->limit) if ($self->limit >= 0);
		push(@str, "Offset=" . $self->offset) if ($self->offset > 0);
		return join(' ', @str);
	}

	sub as_sparql {
		my $self	= shift;
		my %args	= @_;
		my $level	= $args{level} // 0;
		my $sp		= $args{indent} // '    ';
		my $indent	= $sp x $level;
		my ($child)	= @{ $self->children };
		
		my $sparql;
		if ($child->isa('Attean::Algebra::Project')
				or $child->isa('Attean::Algebra::Distinct')
				or $child->isa('Attean::Algebra::Reduced')) {
			$sparql	= $child->as_sparql( %args );
		} else {
			$sparql	= "${indent}SELECT * WHERE {\n"
				. $child->as_sparql( %args, level => $level+1 )
				. "${indent}}\n";
		}
		$sparql	.= "${indent}LIMIT " . $self->limit . "\n" if ($self->limit >= 0);
		$sparql	.= "${indent}OFFSET " . $self->offset . "\n" if ($self->offset > 0);
		return $sparql;
	}
}

=item * L<Attean::Algebra::Project>

=cut

package Attean::Algebra::Project 0.009 {
	use Types::Standard qw(ArrayRef ConsumerOf);
	use Moo;
	use namespace::clean;

	with 'Attean::API::Algebra', 'Attean::API::UnaryQueryTree';
	with 'Attean::API::SPARQLQuerySerializable';

	has 'variables' => (is => 'ro', isa => ArrayRef[ConsumerOf['Attean::API::Variable']], required => 1);

	sub in_scope_variables {
		my $self	= shift;
		my ($child)	= @{ $self->children };
		my $set		= Set::Scalar->new( $child->in_scope_variables );
		my $proj	= Set::Scalar->new( map { $_->value } @{ $self->variables } );
		return $set->intersection($proj)->elements;
	}
	sub algebra_as_string {
		my $self	= shift;
		return sprintf('Project { %s }', join(' ', map { '?' . $_->value } @{ $self->variables }));
	}
	sub tree_attributes { return qw(variables) };
	sub as_sparql {
		my $self	= shift;
		my %args	= @_;
		my $level	= $args{level} // 0;
		my $sp		= $args{indent} // '    ';
		my $indent	= $sp x $level;
		my ($child)	= @{ $self->children };
		my $order;
		if ($child->isa('Attean::Algebra::OrderBy')) {
			$order	= $child;
			($child)	= @{ $child->children };
		}
		
		my $modifier	= '';
		$modifier		= 'DISTINCT ' if ($args{distinct});
		$modifier		= 'REDUCED ' if ($args{reduced});
		my $pvars		= join(' ', map { $_->as_sparql } @{ $self->variables });
		$pvars			= '*' if ($pvars eq '');
		
		my @pvars	= sort map { $_->does('Attean::API::Variable') ? $_->value : $_->as_sparql } @{ $self->variables };
		my @vars	= sort $child->in_scope_variables;
		my $sparql;
		if (join(' ', @pvars) eq join(' ', @vars)) {
			$sparql	= $child->as_sparql( %args );
		} else {
			$sparql	= "${indent}SELECT $modifier$pvars WHERE {\n"
				. $child->as_sparql( %args, level => $level+1 )
				. "${indent}}\n";
		}
		
		if ($order) {
			$sparql	.= "${indent}ORDER BY " . join(' ', map { $_->as_sparql } @{ $order->comparators }) . "\n";
		}
		
		return $sparql;
	}
}

=item * L<Attean::Algebra::Comparator>

=cut

package Attean::Algebra::Comparator 0.009 {
	use Moo;
	use AtteanX::SPARQL::Constants;
	use AtteanX::SPARQL::Token;
	use Types::Standard qw(Bool ConsumerOf);
	use namespace::clean;

	with 'Attean::API::SPARQLSerializable';

	has 'ascending' => (is => 'ro', isa => Bool, default => 1);
	has 'expression' => (is => 'ro', isa => ConsumerOf['Attean::API::Expression'], required => 1);

	sub tree_attributes { return qw(expression) };
	sub as_string {
		my $self	= shift;
		if ($self->ascending) {
			return 'ASC(' . $self->expression->as_string . ')';
		} else {
			return 'DESC(' . $self->expression->as_string . ')';
		}
	}
	sub as_sparql {
		my $self	= shift;
		if ($self->ascending) {
			return $self->expression->as_sparql;
		} else {
			return 'DESC(' . $self->expression->as_sparql . ')';
		}
	}

	sub sparql_tokens {
		my $self	= shift;
		my $asc		= AtteanX::SPARQL::Token->fast_constructor( KEYWORD, -1, -1, -1, -1, ['ASC'] );
		my $desc	= AtteanX::SPARQL::Token->fast_constructor( KEYWORD, -1, -1, -1, -1, ['DESC'] );
		my $l		= AtteanX::SPARQL::Token->fast_constructor( LPAREN, -1, -1, -1, -1, ['('] );
		my $r		= AtteanX::SPARQL::Token->fast_constructor( RPAREN, -1, -1, -1, -1, [')'] );
		
		my @tokens;
		if ($self->ascending) {
			push(@tokens, $self->expression->sparql_tokens->elements);
		} else {
			push(@tokens, $desc, $l);
			push(@tokens, $self->expression->sparql_tokens->elements);
			push(@tokens, $r);
		}
		return Attean::ListIterator->new( values => \@tokens, item_type => 'AtteanX::SPARQL::Token' );
	}
}

=item * L<Attean::Algebra::OrderBy>

=cut

package Attean::Algebra::OrderBy 0.009 {
	use Moo;
	use AtteanX::SPARQL::Constants;
	use AtteanX::SPARQL::Token;
	use Types::Standard qw(ArrayRef InstanceOf);
	use namespace::clean;
	
	with 'Attean::API::UnionScopeVariables', 'Attean::API::Algebra', 'Attean::API::UnaryQueryTree';
	with 'Attean::API::SPARQLQuerySerializable';
	
	has 'comparators' => (is => 'ro', isa => ArrayRef[InstanceOf['Attean::Algebra::Comparator']], required => 1);
	
	sub tree_attributes { return qw(comparators) };
	sub algebra_as_string {
		my $self	= shift;
		return sprintf('Order { %s }', join(', ', map { $_->as_string } @{ $self->comparators }));
	}
	sub as_sparql {
		my $self	= shift;
		my %args	= @_;
		my $level	= $args{level} // 0;
		my $sp		= $args{indent} // '    ';
		my $indent	= $sp x $level;
		my ($child)	= @{ $self->children };
		
		return "${indent}SELECT * WHERE {\n"
			. $child->as_sparql( %args, level => $level+1 )
			. "${indent}}\n"
			. "${indent}ORDER BY " . join(' ', map { $_->as_sparql } @{ $self->comparators }) . "\n";
	}
}

=item * L<Attean::Algebra::BGP>

=cut

package Attean::Algebra::BGP 0.009 {
	use Moo;
	use Attean::RDF;
	use Set::Scalar;
	use AtteanX::SPARQL::Constants;
	use AtteanX::SPARQL::Token;
	use Types::Standard qw(ArrayRef ConsumerOf);
	use namespace::clean;

	with 'Attean::API::Algebra', 'Attean::API::NullaryQueryTree', 'Attean::API::CanonicalizingBindingSet';
	with 'Attean::API::SPARQLSerializable';
	
	has 'triples' => (is => 'ro', isa => ArrayRef[ConsumerOf['Attean::API::TriplePattern']], default => sub { [] });
	
	sub in_scope_variables {
		my $self	= shift;
		my $set		= Set::Scalar->new();
		foreach my $t (@{ $self->triples }) {
			my @vars	= map { $_->value } grep { $_->does('Attean::API::Variable') } $t->values;
			$set->insert(@vars);
		}
		return $set->elements;
	}
	
	sub sparql_tokens {
		my $self	= shift;
		my @tokens;
		my $dot	= AtteanX::SPARQL::Token->fast_constructor( DOT, -1, -1, -1, -1, ['.'] );
		foreach my $t (@{ $self->triples }) {
			push(@tokens, $t->sparql_tokens->elements);
			push(@tokens, $dot);
		}
		return Attean::ListIterator->new( values => \@tokens, item_type => 'AtteanX::SPARQL::Token' );
	}
	
	sub as_sparql {
		my $self	= shift;
		my %args	= @_;
		my $level	= $args{level} // 0;
		my $sp		= $args{indent} // '    ';
		my $indent	= $sp x $level;
		
		return "${indent}{\n"
			. join('', map { $indent . $sp . $_->as_sparql( %args, level => $level+1 ) } @{ $self->triples })
			. "${indent}}\n";
	}
	
	sub algebra_as_string {
		my $self	= shift;
		return 'BGP { ' . join(', ', map { $_->as_string } @{ $self->triples }) . ' }';
	}
	
	sub elements {
		my $self	= shift;
		return @{ $self->triples };
	}
	
	sub canonicalize {
		my $self	= shift;
		my ($algebra, $mapping)	= $self->canonical_bgp_with_mapping();
		my @proj	= sort map { sprintf("(?v%03d AS $_)", $mapping->{$_}{id}) } grep { $mapping->{$_}{type} eq 'variable' } (keys %$mapping);
		foreach my $var (keys %$mapping) {
			$algebra	= Attean::Algebra::Extend->new(
				children	=> [$algebra],
				variable	=> variable($var),
				expression	=> Attean::ValueExpression->new( value => variable($mapping->{$var}{id}) ),
			);
		}
	}
	
	sub canonical_bgp_with_mapping {
		my $self	= shift;
		my ($triples, $mapping)	= $self->canonical_set_with_mapping();
		my $algebra	= Attean::Algebra::BGP->new( triples => $triples );
		return ($algebra, $mapping);
	}
	sub tree_attributes { return qw(triples) };
}

=item * L<Attean::Algebra::Service>

=cut

package Attean::Algebra::Service 0.009 {
	use AtteanX::SPARQL::Constants;
	use AtteanX::SPARQL::Token;
	use Moo;
	use Types::Standard qw(ConsumerOf Bool);
	use namespace::clean;

	with 'Attean::API::Algebra', 'Attean::API::UnaryQueryTree', 'Attean::API::UnionScopeVariables';
	with 'Attean::API::SPARQLSerializable';

	has 'endpoint' => (is => 'ro', isa => ConsumerOf['Attean::API::TermOrVariable'], required => 1);
	has 'silent' => (is => 'ro', isa => Bool, default => 0);
	
	sub algebra_as_string {
		my $self	= shift;
		return sprintf('Service %s', $self->endpoint->as_string);
	}

	sub tree_attributes { return qw(endpoint) };
	sub as_sparql {
		my $self	= shift;
		my %args	= @_;
		my $level	= $args{level} // 0;
		my $sp		= $args{indent} // '    ';
		my $indent	= $sp x $level;
		
		my ($child)	= @{ $self->children };
		my $ep		= $self->endpoint->as_sparql;
		return "${indent}SERVICE $ep {\n"
			. $child->as_sparql( %args, level => $level+1 )
			. "${indent}}\n";
	}

	sub sparql_tokens {
		my $self	= shift;
		my $service	= AtteanX::SPARQL::Token->fast_constructor( KEYWORD, -1, -1, -1, -1, ['SERVICE'] );
		my $l		= AtteanX::SPARQL::Token->fast_constructor( LBRACE, -1, -1, -1, -1, ['{'] );
		my $r		= AtteanX::SPARQL::Token->fast_constructor( RBRACE, -1, -1, -1, -1, ['}'] );
		my ($child)	= @{ $self->children };
		
		my @tokens;
		push(@tokens, $service);
		push(@tokens, $self->endpoint->sparql_tokens->elements);
		push(@tokens, $l);
		push(@tokens, $child->sparql_tokens->elements);
		push(@tokens, $r);
		return Attean::ListIterator->new( values => \@tokens, item_type => 'AtteanX::SPARQL::Token' );
	}
}

=item * L<Attean::Algebra::Path>

=cut

package Attean::Algebra::Path 0.009 {
	use Moo;
	use AtteanX::SPARQL::Constants;
	use AtteanX::SPARQL::Token;
	use Types::Standard qw(ArrayRef ConsumerOf);
	use namespace::clean;

	with 'Attean::API::Algebra', 'Attean::API::NullaryQueryTree';
	with 'Attean::API::SPARQLSerializable';

	has 'subject' => (is => 'ro', isa => ConsumerOf['Attean::API::TermOrVariable'], required => 1);
	has 'path' => (is => 'ro', isa => ConsumerOf['Attean::API::PropertyPath'], required => 1);
	has 'object' => (is => 'ro', isa => ConsumerOf['Attean::API::TermOrVariable'], required => 1);

	sub in_scope_variables {
		my $self	= shift;
		my @vars	= map { $_->value } grep { $_->does('Attean::API::Variable') } ($self->subject, $self->object);
		return Set::Scalar->new(@vars)->elements;
	}

	sub tree_attributes { return qw(subject path object) };

	sub algebra_as_string {
		my $self	= shift;
		return 'Path { ' . join(', ', map { $_->as_string } map { $self->$_() } qw(subject path object)) . ' }';
	}

	sub as_sparql {
		my $self	= shift;
		my %args	= @_;
		my $level	= $args{level} // 0;
		my $sp		= $args{indent} // '    ';
		my $indent	= $sp x $level;
		
		return "${indent}"
			. $self->subject->as_sparql
			. ' '
			. $self->path->as_sparql
			. ' '
			. $self->object->as_sparql
			. "\n";
	}

	sub sparql_tokens {
		my $self	= shift;

		my @tokens;
		foreach my $t ($self->subject, $self->path, $self->object) {
			push(@tokens, $t->sparql_tokens->elements);
		}
		return Attean::ListIterator->new( values => \@tokens, item_type => 'AtteanX::SPARQL::Token' );
	}
}

=item * L<Attean::Algebra::Group>

=cut

package Attean::Algebra::Group 0.009 {
	use utf8;
	use Moo;
	use AtteanX::SPARQL::Constants;
	use AtteanX::SPARQL::Token;
	use Types::Standard qw(ArrayRef ConsumerOf);
	use namespace::clean;
	
	with 'Attean::API::Algebra', 'Attean::API::UnaryQueryTree';
	with 'Attean::API::SPARQLQuerySerializable';

	has 'groupby' => (is => 'ro', isa => ArrayRef[ConsumerOf['Attean::API::Expression']]);
	has 'aggregates' => (is => 'ro', isa => ArrayRef[ConsumerOf['Attean::API::AggregateExpression']]);
	
	sub BUILD {
		my $self	= shift;
		foreach my $a (@{ $self->aggregates }) {
			my $op	= $a->operator;
			if ($op eq 'RANK') {
				if (scalar(@{ $self->aggregates }) > 1) {
					die "Cannot use both aggregates and RANKing in grouping operator";
				}
			}
		}
	}
	
	sub in_scope_variables {
		my $self	= shift;
		my $aggs	= $self->aggregates // [];
		my @vars;
		foreach my $a (@$aggs) {
			push(@vars, $a->variable->value);
		}
		return @vars;
	}
	sub algebra_as_string {
		my $self	= shift;
		my @aggs;
		my $aggs	= $self->aggregates // [];
		my $groups	= $self->groupby // [];
		foreach my $a (@$aggs) {
			my $v	= $a->variable->as_sparql;
			my $op	= $a->operator;
			my $d	= $a->distinct ? "DISTINCT " : '';
			my ($e)	= ((map { $_->as_sparql } @{ $a->children }), '');
			push(@aggs, "$v ← ${op}($d$e)");
		}
		return sprintf('Group { %s } aggregate { %s }', join(', ', map { $_->as_sparql() } @$groups), join(', ', @aggs));
	}

	sub tree_attributes { return qw(groupby aggregates) };
	sub as_sparql {
		my $self	= shift;
		my %args	= @_;
		my $level	= $args{level} // 0;
		my $sp		= $args{indent} // '    ';
		my $indent	= $sp x $level;
		my $groups	= $self->groupby // [];
		my $aggs	= $self->aggregates // [];
		my %vmap	= %{ $args{ aggregate_variables } // {} };
		my @aggs;
		foreach my $a (@$aggs) {
			my $av	= $a->variable->value;
			my $v	= exists $vmap{$av} ? $vmap{$av} : $av;
			my $op	= $a->operator;
			my $d	= $a->distinct ? "DISTINCT " : '';
			my ($e)	= map { $_->value->as_sparql } @{ $a->children };
			push(@aggs, "(${op}($d$e) AS $v)");
		}
		
		warn "TODO: as_sparql serialization of GROUPing";
		my $sparql	= "${indent}SELECT " . join(' ', @aggs) . " WHERE {\n"
			. join('', map { $_->as_sparql( %args, level => $level+1 ) } @{ $self->children })
			. "${indent}}";
		if (scalar(@$groups)) {
			my @g	= map { $_->as_sparql() } @$groups;
			$sparql	.= " GROUP BY " . join(' ', @g);
		}
		$sparql	.= "\n";
		return $sparql;
	}
}

=item * L<Attean::Algebra::NegatedPropertySet>

=cut

package Attean::Algebra::NegatedPropertySet 0.009 {
	use Moo;
	use AtteanX::SPARQL::Constants;
	use AtteanX::SPARQL::Token;
	use Types::Standard qw(ArrayRef ConsumerOf);
	use namespace::clean;

	with 'Attean::API::PropertyPath';
	with 'Attean::API::SPARQLSerializable';

	has 'predicates' => (is => 'ro', isa => ArrayRef[ConsumerOf['Attean::API::IRI']], required => 1);
	
	sub as_string {
		my $self	= shift;
		return sprintf("!(%s)", join('|', map { $_->ntriples_string } @{ $self->predicates }));
	}
	sub algebra_as_string { return 'NPS' }
	sub tree_attributes { return qw(predicates) };
	sub as_sparql {
		my $self	= shift;
		return "!(" . join('|', map { $_->as_sparql } @{$self->predicates}) . ")";
	}

	sub sparql_tokens {
		my $self	= shift;
		my $bang	= AtteanX::SPARQL::Token->fast_constructor( BANG, -1, -1, -1, -1, ['!'] );
		my $or		= AtteanX::SPARQL::Token->fast_constructor( OR, -1, -1, -1, -1, ['|'] );
		my $l		= AtteanX::SPARQL::Token->fast_constructor( LPAREN, -1, -1, -1, -1, ['('] );
		my $r		= AtteanX::SPARQL::Token->fast_constructor( RPAREN, -1, -1, -1, -1, [')'] );

		my @tokens;
		push(@tokens, $bang, $l);
		foreach my $t (@{ $self->predicates }) {
			push(@tokens, $t->sparql_tokens->elements);
			push(@tokens, $or);
		}
		pop(@tokens); # remove last OR token
		push(@tokens, $r);
		return Attean::ListIterator->new( values => \@tokens, item_type => 'AtteanX::SPARQL::Token' );
	}
}

=item * L<Attean::Algebra::PredicatePath>

=cut

package Attean::Algebra::PredicatePath 0.009 {
	use Moo;
	use Types::Standard qw(ConsumerOf);
	use namespace::clean;

	with 'Attean::API::PropertyPath';
	with 'Attean::API::SPARQLSerializable';

	has 'predicate' => (is => 'ro', isa => ConsumerOf['Attean::API::IRI'], required => 1);
	sub as_string {
		my $self	= shift;
		return $self->predicate->ntriples_string;
	}
	sub algebra_as_string {
		my $self	= shift;
		return 'Property Path ' . $self->as_string;
	}
	sub tree_attributes { return qw(predicate) };
	sub as_sparql {
		my $self	= shift;
		return $self->predicate->as_sparql;
	}

	sub sparql_tokens {
		my $self	= shift;
		return $self->predicate->sparql_tokens;
	}
	
}

=item * L<Attean::Algebra::InversePath>

=cut

package Attean::Algebra::InversePath 0.009 {
	use Moo;
	use AtteanX::SPARQL::Constants;
	use AtteanX::SPARQL::Token;
	use Types::Standard qw(ConsumerOf);
	use namespace::clean;

	with 'Attean::API::UnaryPropertyPath';
	with 'Attean::API::SPARQLSerializable';

	sub prefix_name { return "^" }
	sub as_sparql {
		my $self	= shift;
		my ($path)	= @{ $self->children };
		return '^' . $self->path->as_sparql;
	}

	sub sparql_tokens {
		my $self	= shift;
		my $hat		= AtteanX::SPARQL::Token->fast_constructor( HAT, -1, -1, -1, -1, ['^'] );
		my $l		= AtteanX::SPARQL::Token->fast_constructor( LPAREN, -1, -1, -1, -1, ['('] );
		my $r		= AtteanX::SPARQL::Token->fast_constructor( RPAREN, -1, -1, -1, -1, [')'] );

		my @tokens;
		foreach my $t (@{ $self->children }) {
			push(@tokens, $t->sparql_tokens->elements);
		}
		
		if (scalar(@tokens) > 1) {
			unshift(@tokens, $hat, $l);
			push(@tokens, $r);
		} else {
			unshift(@tokens, $hat);
		}
		
		return Attean::ListIterator->new( values => \@tokens, item_type => 'AtteanX::SPARQL::Token' );
	}
}

=item * L<Attean::Algebra::SequencePath>

=cut

package Attean::Algebra::SequencePath 0.009 {
	use Moo;
	use AtteanX::SPARQL::Constants;
	use AtteanX::SPARQL::Token;
	use namespace::clean;

	with 'Attean::API::NaryPropertyPath';
	with 'Attean::API::SPARQLSerializable';

	sub separator { return "/" }
	sub as_sparql {
		my $self	= shift;
		my @paths	= @{ $self->children };
		return '(' . join('/', map { $_->as_sparql } @paths) . ')';
	}

	sub sparql_tokens {
		my $self	= shift;
		my $slash	= AtteanX::SPARQL::Token->fast_constructor( SLASH, -1, -1, -1, -1, ['/'] );

		my @tokens;
		foreach my $t (@{ $self->children }) {
			push(@tokens, $t->sparql_tokens->elements);
			push(@tokens, $slash);
		}
		pop(@tokens); # remove last SLASH token
		return Attean::ListIterator->new( values => \@tokens, item_type => 'AtteanX::SPARQL::Token' );
	}
}

=item * L<Attean::Algebra::AlternativePath>

=cut

package Attean::Algebra::AlternativePath 0.009 {
	use Moo;
	use AtteanX::SPARQL::Constants;
	use AtteanX::SPARQL::Token;
	use namespace::clean;

	with 'Attean::API::NaryPropertyPath';
	with 'Attean::API::SPARQLSerializable';

	sub separator { return "|" }
	sub as_sparql {
		my $self	= shift;
		my @paths	= @{ $self->children };
		return '(' . join('|', map { $_->as_sparql } @paths) . ')';
	}

	sub sparql_tokens {
		my $self	= shift;
		my $or		= AtteanX::SPARQL::Token->fast_constructor( OR, -1, -1, -1, -1, ['|'] );

		my @tokens;
		foreach my $t (@{ $self->children }) {
			push(@tokens, $t->sparql_tokens->elements);
			push(@tokens, $or);
		}
		pop(@tokens); # remove last OR token
		return Attean::ListIterator->new( values => \@tokens, item_type => 'AtteanX::SPARQL::Token' );
	}
}

=item * L<Attean::Algebra::ZeroOrMorePath>

=cut

package Attean::Algebra::ZeroOrMorePath 0.009 {
	use Moo;
	use AtteanX::SPARQL::Constants;
	use AtteanX::SPARQL::Token;
	use Types::Standard qw(ConsumerOf);
	use namespace::clean;

	with 'Attean::API::UnaryPropertyPath';
	with 'Attean::API::SPARQLSerializable';

	sub postfix_name { return "*" }
	sub as_sparql {
		my $self	= shift;
		my ($path)	= @{ $self->children };
		return $self->path->as_sparql . '*';
	}
	
	sub sparql_tokens {
		my $self	= shift;
		my $star	= AtteanX::SPARQL::Token->fast_constructor( STAR, -1, -1, -1, -1, ['*'] );
		my $l		= AtteanX::SPARQL::Token->fast_constructor( LPAREN, -1, -1, -1, -1, ['('] );
		my $r		= AtteanX::SPARQL::Token->fast_constructor( RPAREN, -1, -1, -1, -1, [')'] );

		my @tokens;
		foreach my $t (@{ $self->children }) {
			push(@tokens, $t->sparql_tokens->elements);
		}
		
		if (scalar(@tokens) > 1) {
			unshift(@tokens, $l);
			push(@tokens, $r);
		}
		push(@tokens, $star);
		
		return Attean::ListIterator->new( values => \@tokens, item_type => 'AtteanX::SPARQL::Token' );
	}
}

=item * L<Attean::Algebra::OneOrMorePath>

=cut

package Attean::Algebra::OneOrMorePath 0.009 {
	use Moo;
	use AtteanX::SPARQL::Constants;
	use AtteanX::SPARQL::Token;
	use Types::Standard qw(ConsumerOf);
	use namespace::clean;

	with 'Attean::API::UnaryPropertyPath';
	with 'Attean::API::SPARQLSerializable';

	sub postfix_name { return "+" }
	sub as_sparql {
		my $self	= shift;
		my ($path)	= @{ $self->children };
		return $self->path->as_sparql . '+';
	}

	sub sparql_tokens {
		my $self	= shift;
		my $plus	= AtteanX::SPARQL::Token->fast_constructor( PLUS, -1, -1, -1, -1, ['+'] );
		my $l		= AtteanX::SPARQL::Token->fast_constructor( LPAREN, -1, -1, -1, -1, ['('] );
		my $r		= AtteanX::SPARQL::Token->fast_constructor( RPAREN, -1, -1, -1, -1, [')'] );

		my @tokens;
		foreach my $t (@{ $self->children }) {
			push(@tokens, $t->sparql_tokens->elements);
		}
		
		if (scalar(@tokens) > 1) {
			unshift(@tokens, $l);
			push(@tokens, $r);
		}
		push(@tokens, $plus);
		
		return Attean::ListIterator->new( values => \@tokens, item_type => 'AtteanX::SPARQL::Token' );
	}
}

=item * L<Attean::Algebra::ZeroOrOnePath>

=cut

package Attean::Algebra::ZeroOrOnePath 0.009 {
	use Moo;
	use AtteanX::SPARQL::Constants;
	use AtteanX::SPARQL::Token;
	use Types::Standard qw(ConsumerOf);
	use namespace::clean;

	with 'Attean::API::UnaryPropertyPath';
	with 'Attean::API::SPARQLSerializable';

	sub postfix_name { return "?" }
	sub as_sparql {
		my $self	= shift;
		my ($path)	= @{ $self->children };
		return $self->path->as_sparql . '?';
	}

	sub sparql_tokens {
		my $self	= shift;
		my $q		= AtteanX::SPARQL::Token->fast_constructor( QUESTION, -1, -1, -1, -1, ['?'] );
		my $l		= AtteanX::SPARQL::Token->fast_constructor( LPAREN, -1, -1, -1, -1, ['('] );
		my $r		= AtteanX::SPARQL::Token->fast_constructor( RPAREN, -1, -1, -1, -1, [')'] );

		my @tokens;
		foreach my $t (@{ $self->children }) {
			push(@tokens, $t->sparql_tokens->elements);
		}
		
		if (scalar(@tokens) > 1) {
			unshift(@tokens, $l);
			push(@tokens, $r);
		}
		push(@tokens, $q);
		
		return Attean::ListIterator->new( values => \@tokens, item_type => 'AtteanX::SPARQL::Token' );
	}
}

=item * L<Attean::Algebra::Table>

=cut

package Attean::Algebra::Table 0.009 {
	use Moo;
	use AtteanX::SPARQL::Constants;
	use AtteanX::SPARQL::Token;
	use Types::Standard qw(ArrayRef ConsumerOf);
	use namespace::clean;

	with 'Attean::API::Algebra', 'Attean::API::UnaryQueryTree';
	with 'Attean::API::SPARQLSerializable';

	has variables => (is => 'ro', isa => ArrayRef[ConsumerOf['Attean::API::Variable']]);
	has rows => (is => 'ro', isa => ArrayRef[ConsumerOf['Attean::API::Result']]);

	sub in_scope_variables {
		my $self	= shift;
		return map { $_->value } @{ $self->variables };
	}
	sub tree_attributes { return qw(variables rows) };
	sub algebra_as_string { return 'Table' }
	sub as_sparql {
		my $self	= shift;
		my %args	= @_;
		my $level	= $args{level} // 0;
		my $sp		= $args{indent} // '    ';
		my $indent	= $sp x $level;
		
		my $sparql	= "${indent}VALUES (" . join(' ', map { $_->as_sparql } @{ $self->variables }) . ") {\n";
		foreach my $row (@{ $self->rows }) {
			$sparql	.= "${indent}${sp}(" . join(' ', map { $_->as_sparql } $row->values) . ")\n";
		}
		$sparql		.= "${indent}}\n";
		return $sparql;
	}

	sub sparql_tokens {
		my $self	= shift;
		my $values	= AtteanX::SPARQL::Token->fast_constructor( KEYWORD, -1, -1, -1, -1, ['VALUES'] );
		my $lparen	= AtteanX::SPARQL::Token->fast_constructor( LPAREN, -1, -1, -1, -1, ['('] );
		my $rparen	= AtteanX::SPARQL::Token->fast_constructor( RPAREN, -1, -1, -1, -1, [')'] );
		my $lbrace	= AtteanX::SPARQL::Token->fast_constructor( LBRACE, -1, -1, -1, -1, ['{'] );
		my $rbrace	= AtteanX::SPARQL::Token->fast_constructor( RBRACE, -1, -1, -1, -1, ['}'] );

		my @tokens;
		push(@tokens, $values, $lparen);
		foreach my $var (@{ $self->variables }) {
			push(@tokens, $var->sparql_tokens->elements);
		}
		push(@tokens, $values, $rparen);
		
		push(@tokens, $values, $lbrace);
		foreach my $row (@{ $self->rows }) {
			push(@tokens, $lparen);
			foreach my $val ($row->values) {
				# TODO: verify correct serialization of UNDEF
				push(@tokens, $val->sparql_tokens->elements);
			}
			push(@tokens, $rparen);
		}
		push(@tokens, $values, $rbrace);
		
		return Attean::ListIterator->new( values => \@tokens, item_type => 'AtteanX::SPARQL::Token' );
	}
}

=item * L<Attean::Algebra::Ask>

=cut

package Attean::Algebra::Ask 0.009 {
	use Moo;
	use AtteanX::SPARQL::Constants;
	use AtteanX::SPARQL::Token;
	use namespace::clean;
	
	with 'Attean::API::Algebra', 'Attean::API::UnaryQueryTree';
	with 'Attean::API::SPARQLQuerySerializable';
	
	sub in_scope_variables { return; }

	sub algebra_as_string { return 'Ask' }
	sub as_sparql {
		my $self	= shift;
		my %args	= @_;
		my $level	= $args{level} // 0;
		my $sp		= $args{indent} // '    ';
		my $indent	= $sp x $level;
		
		return "${indent}ASK {\n"
			. join('', map { $_->as_sparql( %args, level => $level+1 ) } @{ $self->children })
			. "${indent}}\n";
	}
}

=item * L<Attean::Algebra::Construct>

=cut

package Attean::Algebra::Construct 0.009 {
	use Moo;
	use AtteanX::SPARQL::Constants;
	use AtteanX::SPARQL::Token;
	use Types::Standard qw(ArrayRef ConsumerOf);
	use namespace::clean;
	
	with 'Attean::API::Algebra', 'Attean::API::UnaryQueryTree';
	with 'Attean::API::SPARQLQuerySerializable';

	has 'triples' => (is => 'ro', isa => ArrayRef[ConsumerOf['Attean::API::TriplePattern']]);

	sub in_scope_variables { return qw(subject predicate object); }
	sub tree_attributes { return qw(triples) };
	sub algebra_as_string { return 'Construct' }
	sub as_sparql {
		my $self	= shift;
		my %args	= @_;
		my $level	= $args{level} // 0;
		my $sp		= $args{indent} // '    ';
		my $indent	= $sp x $level;
		
		return "${indent}CONSTRUCT {\n"
			. join('', map { $_->as_sparql( %args, level => $level+1 ) } @{ $self->triples })
			. "${indent}} WHERE {\n"
			. join('', map { $_->as_sparql( %args, level => $level+1 ) } @{ $self->children })
			. "${indent}}\n";
	}
}


1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/attean/issues>.

=head1 SEE ALSO

L<http://www.perlrdf.org/>

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2014 Gregory Todd Williams.
This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
