=head1 NAME

AtteanX::Serializer::SPARQL - SPARQL Serializer

=head1 VERSION

This document describes AtteanX::Serializer::SPARQL version 0.009

=head1 SYNOPSIS

 use Attean;
 my $serializer = Attean->get_serializer('SPARQL')->new();
 $serializer->serialize_iter_to_io( $io, $fh );

=head1 DESCRIPTION

...

=head1 METHODS

=over 4

=cut

use v5.14;
use warnings;

package AtteanX::Serializer::SPARQL 0.009 {
	use Moo;
	use Data::Dumper;
	use Encode qw(encode);
	use Attean::ListIterator;
	use List::MoreUtils qw(any);
	use AtteanX::SPARQL::Constants;
	use namespace::clean;
	with 'Attean::API::AbbreviatingSerializer';
	
	sub canonical_media_type { return "application/sparql-query" }

	sub media_types {
		return [qw(application/sparql-query)];
	}
	
	sub handled_type {
		state $ITEM_TYPE = Type::Tiny::Role->new(role => 'AtteanX::SPARQL::Token');
		return $ITEM_TYPE;
	}

	sub file_extensions { return [qw(rq)] }

=item C<< serialize_iter_to_io( $fh, $iterator ) >>

Serializes the SPARQL token objects from C<< $iterator >> to the
L<IO::Handle> object C<< $fh >>.

=cut

	sub serialize_iter_to_io {
		my $self	= shift;
		my $io		= shift;
		my $iter	= shift;
		my $indent		= 0;
		my $newline		= 1;
		my $semicolon	= 0;
		my $need_space	= 0;
		while (my $t = $iter->next()) {
			my $type	= $t->type;
			
			if ($type == LANG or $type == HATHAT) {
				$need_space= 0;
			}
			
			unless ($newline) {
				if ($type == RBRACE) {
					$io->print("\n");
					$newline	= 1;
					$indent--;
				} elsif ($type == KEYWORD and $t->value =~ /^(BASE|PREFIX|SELECT|ASK|CONSTRUCT|DESCRIBE)$/) {
					$io->print("\n");
					$newline	= 1;
				}
			}
			
			if ($newline) {
				$io->print('    ' x $indent);
				$newline	= 0;
			} elsif ($need_space) {
				$io->print(' ');
				$need_space	= 0;
			}
			
			if ($type == KEYWORD) {
				$io->print($t->value);
				$need_space++;
			} elsif ($type == PREFIXNAME) {
				my $args	= $t->args;
				$io->print(join('', @$args));
				$need_space++;
			} elsif ($type == IRI) {
				# TODO: escape
				$io->print('<');
				$io->print($t->value);
				$io->print('>');
				$need_space++;
			} elsif ($type == LANG) {
				$io->print('@');
				$io->print($t->value);
				$need_space++;
			} elsif ($type == STRING1S) {
				my $value	= $t->value;
				$value		=~ s/'/\\'/g;
				$io->print("'");
				$io->print($value);
				$io->print("'");
				$need_space++;
			} elsif ($type == STRING1D) {
				my $value	= $t->value;
				$value		=~ s/"/\\"/g;
				$io->print('"');
				$io->print($value);
				$io->print('"');
				$need_space++;
			} elsif ($type == STRING3S) {
				my $value	= $t->value;
				$value		=~ s/'''/''\\'/g;
				$io->print("'''");
				$io->print($value);
				$io->print("'''");
				$need_space++;
			} elsif ($type == STRING3D) {
				my $value	= $t->value;
				$value		=~ s/"""/""\\"/g;
				$io->print('"""');
				$io->print($value);
				$io->print('"""');
				$need_space++;
			} elsif ($type == VAR) {
				$io->print('?');
				$io->print($t->value);
				$need_space++;
			} elsif ($type == A) {
				$io->print('a');
				$need_space++;
			} elsif ($type == WS) {
			} elsif ($type == COMMENT) {
				$io->print('# ');
				$io->print($t->value);
				$io->print("\n");
			} elsif ($type == HATHAT) {
				$io->print($t->value);
			} else {
				$io->print($t->value);
				$need_space++;
			}
			
			if ($type == DOT and $semicolon) {
				$indent--;
				$need_space	= 0;
				$io->print("\n");
				$newline	= 1;
				$semicolon	= 0;
			} elsif ($type == LBRACE) {
				$io->print("\n");
				$need_space	= 0;
				$newline	= 1;
				$indent++;
			} elsif ($type == SEMICOLON) {
				$io->print("\n");
				$need_space	= 0;
				$newline	= 1;
				$semicolon	= 1;
				unless ($semicolon) {
					$indent++;
				}
			}
		}
		$io->print("\n");
		return;
	}
	
=item C<< serialize_iter_to_bytes( $fh, $iterator ) >>

Serializes the SPARQL token objects from C<< $iterator >>
and returns the serialization as a UTF-8 encoded byte string.

=cut

	sub serialize_iter_to_bytes {
		my $self	= shift;
		my $iter	= shift;
		my $data	= '';
		open(my $fh, '>:utf8', \$data);
		$self->serialize_iter_to_io($fh);
		close($fh);
		return $data;
	}
}

1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
