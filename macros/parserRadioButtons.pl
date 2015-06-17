################################################################################
# WeBWorK Online Homework Delivery System
# Copyright � 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader$
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

=head1 NAME

parserRadioButtons.pl - Radio buttons compatible with Value objects, specifically MultiAnswer objects.

=head1 DESCRIPTION

This file implements a radio button group object that is compatible
with Value objects, and in particular, with the MultiAnswer object.

To create a RadioButtons object, use

	$radio = RadioButtons([choices,...],correct,options);

where "choices" are the strings for the items in the radio buttons,
"correct" is the choice that is the correct answer for the group,
and options are chosen from among:

=over

=item C<S<< order => [choice,...] >>>

Specifies the order in which choices should be presented. All choices must be
listed. If this option is specified, the C<first> and C<last> options are
ignored.

=item C<S<< first => [choice,...] >>>

Specifies choices which should appear first, in the order specified, in the list
of choices. Ignored if the C<order> option is specified.

=item C<S<< last => [choice,...] >>>

Specifies choices which should appear last, in the order specified, in the list
of choices. Ignored if the C<order> option is specified.

=item C<S<< labels => [label1,...] >>>

Specifies the text to be used
as the student answer for each
entry in the radio group.
This can also be set to the string
"ABC" to get lettered labels or
"123" to get numbered labels.
The default is to use a few words
from the text string for each button.

=item C<S<< separator => string >>>

text to put between the radio
buttons.
Default: $BR

=item C<S<< checked => choice >>>

the text or index (starting at zero)
of the button to be checked
Default: none checked

=item C<S<< maxLabelSize => n >>>

the approximate largest size that should
be used for the answer strings to be
generated by the radio buttons (if
the choice strings are too long, they
will be trimmed and "..." inserted)
Default: 25

=item C<S<< uncheckable => 0 or 1 or "shift" >>>

determines whether the radio buttons can
be unchecked (requires JavaScript).
To uncheck, click a second time; when
set to "shift", unchecking requires the
shift key to be pressed.
Default: 0

=back

To insert the radio buttons into the problem text, use

	BEGIN_TEXT
	\{$radio->buttons\}
	END_TEXT

and then

	ANS($radio->cmp);

to get the answer checker for the radion buttons.

You can use the RadioButtons object in MultiPart objects.  This is
the reason for the RadioButton's ans_rule method (since that is what
MultiPart calls to get answer rules).

=cut

loadMacros('MathObjects.pl','contextString.pl');

sub _parserRadioButtons_init {parserRadioButtons::Init()}; # don't reload this file

##################################################
#
#  The package that implements RadioButtons
#
package parserRadioButtons;
our @ISA = qw(Value::String);

my $jsPrinted = 0;  # true when the JavaScript has been printed

#
#  Set up the main:: namespace
#
sub Init {
  $jsPrinted = 0;
  main::PG_restricted_eval('sub RadioButtons {parserRadioButtons->new(@_)}');
}

#
#  Create a new RadioButtons object
#
sub new {
  my $self = shift; my $class = ref($self) || $self;
  my $context = (Value::isContext($_[0]) ? shift : $self->context);
  my $choices = shift; my $value = shift;
  my %options;
  main::set_default_options(\%options,
    labels => [],
    separator => $main::BR,
    checked => undef,
    maxLabelSize => 25,
    uncheckable => 0,
    first => undef,
    last => undef,
    order => undef,
    @_,
  );
  $options{labels} = [1..scalar(@$choices)] if $options{labels} eq "123";
  $options{labels} = [@main::ALPHABET[0..scalar(@$choices)-1]] if $options{labels} eq "ABC";
  my $self = bless {%options, choices=>$choices}, $class; # temporary to so we can call our methods
  Value::Error("A RadioButton's first argument should be a list of button labels")
    unless ref($choices) eq 'ARRAY';
  Value::Error("A RadioButton's second argument should be the correct button choice")
    unless defined($value) && $value ne "";
  my $context = Parser::Context->getCopy("String");
  my %choiceHash = $self->choiceHash;
  $context->strings->add(map {$_=>{}} (keys %choiceHash));
  $value = $self->correctChoice($value);
  $self = bless $context->Package("String")->new($context,$value)->with(choices => $choices, %options), $class;
  $self->JavaScript if $self->{uncheckable};
  return $self;
}

#
#  Given a choice, a label, or an index into the choices array,
#    return the label.
#
sub findChoice {
  my $self = shift; my $value = shift;
  my $index = $self->Index($value);
  foreach my $i (0..scalar(@{$self->{choices}})-1) {
    my $label = $self->{labels}[$i]; my $choice = $self->{choices}[$i];
    $label = $choice unless defined $label;
    return $label if $label eq $value || $index == $i || $choice eq $value;
  }
  return undef;
}

#
#  Locate the label of the correct answer
#  The answer can be given as an index, as the full answer
#    or as the label itself.
#
sub correctChoice {
  my $self = shift; my $value = shift;
  my $choice = $self->findChoice($value);
  return $choice if defined $choice;
  Value::Error("The correct answer should be one of the button choices");
}

#
#  Create the hash of label => answer pairs to be used for the
#  ans_radio_buttons() routine
#
sub choiceHash {
  my $self = shift; my @radio = (); my %labels;
  foreach my $i (0..scalar(@{$self->{choices}})-1) {
    my $label = $self->{labels}[$i]; my $choice = $self->{choices}[$i];
    $label = $choice unless defined $label;
    push(@radio, $label,$choice);
  }
  return @radio;
}

#
#  Create a label for the answer, either using the labels
#  provided by the author, or by creating one from the answer
#  string (restrict its length so that the results table
#  will not be overflowed).
#
sub labelText {
  my $self = shift; my $choice = shift;
  return $choice if length($choice) < $self->{maxLabelSize};
  my @words = split(/\b/,$choice); my ($s,$e) = ('','');
  do {$s .= shift(@words); $e = pop(@words) . $e}
    while length($s) + length($e) + 15 < $self->{maxLabelSize} && scalar(@words);
  return $s . " ... " . $e;
}

#
#  Get a numeric index (-1 if not defined or not a number)
#
sub Index {
  my $self = shift; my $index = shift;
  return -1 unless defined $index && $index =~ m/^\d$/;
  return $index;
}

#
#  Print the JavaScript needed for uncheckable radio buttons
#
sub JavaScript {
  return if $jsPrinted || $main::displayMode eq 'TeX';
  main::TEXT(
    "\n<script>\n" .
    "if (window.ww == null) {var ww = {}}\n" .
    "if (ww.RadioButtons == null) {ww.RadioButtons = {}}\n" .
    "if (ww.RadioButtons.selected == null) {ww.RadioButtons.selected = {}}\n" .
    "ww.RadioButtons.Toggle = function (obj,event,shift) {\n" .
    "  if (!event) {event = window.event}\n" .
    "  if (shift && !event.shiftKey) {\n" .
    "    this.selected[obj.name] = obj\n" .
    "    return\n" .
    "  }\n" .
    "  var selected = this.selected[obj.name]\n" .
    "  if (selected && selected == obj) {\n".
    "    this.selected[obj.name] = null\n" .
    "    obj.checked = false\n" .
    "  } else {\n" .
    "    this.selected[obj.name] = obj\n".
    "  }\n" .
    "}\n".
    "</script>\n"
  );
  $jsPrinted = 1;
}

sub makeUncheckable {
  my $self = shift;
  my $shift = ($self->{uncheckable} =~ m/shift/i ? ",1" : "");
  my $onclick = "onclick=\"ww.RadioButtons.Toggle(this,event$shift)\"";
  my @radio = @_;
  foreach (@radio) {$_ =~ s/<INPUT/<INPUT $onclick/i}
  return @radio;
}

#
#  Determine the order the choices should be in.
#
sub orderedChoices {
  my $self = shift;
  my %choiceHash = $self->choiceHash;
  my @labels = keys %choiceHash;

  my @order = @{$self->{order} || []};
  my @first = @{$self->{first} || []};
  my @last  = @{$self->{last}  || []};

  my @orderLabels;

  if (@order) {
    my %remainingChoices = %choiceHash;
    Value::Error("When using the 'order' option, you must list all possible choices.")
      unless @order == @labels;
    foreach my $i (0..$#order) {
      my $label = $self->findChoice($order[$i]);
      Value::Error("Item $i of the 'order' option is not a choice.")
      	if not defined $label;
      Value::Error("Item $i of the 'order' option was already specified.")
      	if not exists $remainingChoices{$label};
      push @orderLabels, $label;
      delete $remainingChoices{$label};
    }
  } elsif (@first or @last) {
    my @firstLabels;
    my @lastLabels;
    my %remainingChoices = %choiceHash;

    foreach my $i (0..$#first) {
      my $label = $self->findChoice($first[$i]);
      Value::Error("Item $i of the 'first' option is not a choice.")
	if not defined $label;
      Value::Error("Item $i of the 'first' option was already specified.")
	if not exists $remainingChoices{$label};
      push @firstLabels, $label;
      delete $remainingChoices{$label};
    }

    foreach my $i (0..$#last) {
      my $label = $self->findChoice($last[$i]);
      Value::Error("Item $i of the 'last' option is not a choice.")
	if not defined $label;
      Value::Error("Item $i of the 'last' option was already specified.")
	if not exists $remainingChoices{$label};
      push @lastLabels, $label;
      delete $remainingChoices{$label};
    }

    @orderLabels = (@firstLabels, keys %remainingChoices, @lastLabels);
  } else {
    # use the order of elements in the hash
    # this is the current behavior
    # might we want to explicitly randomize these?
    @orderLabels = @labels;
  }

  my $label = ($self->{checked} ? $self->findChoice($self->{checked}) : "");
  return map { ($_ eq $label ? "%$_" : $_) => $choiceHash{$_} } @orderLabels;
}

#
#  Create the radio-buttons text
#
sub BUTTONS {
  my $self = shift;
  my $extend = shift; my $name = shift;
  my @choices = $self->orderedChoices;
  my @radio = ();
  $name = main::NEW_ANS_NAME() unless $name;
  my $label = main::generate_aria_label($name);
  my $count = 1;
  while (@choices) {
    my $value = shift(@choices); my $tag = shift(@choices);
    if ($extend) {
      push(@radio,main::NAMED_ANS_RADIO_EXTENSION($name,$value,$tag,
	   aria_label=>$label."option $count "));
    } else {
      push(@radio,main::NAMED_ANS_RADIO($name,$value,$tag));
      $extend = true;
    }
    $count++;
  }
  #
  #  Taken from PGbasicmacros.pl
  #  It is wrong to have \item in the radio buttons and to add itemize here,
  #    but that is the way PGbasicmacros.pl does it.
  #
  if ($main::displayMode eq 'TeX') {
    $radio[0] = "\n\\begin{itemize}\n" . $radio[0];
    $radio[$#radio_buttons] .= "\n\\end{itemize}\n";
  }
  @radio = $self->makeUncheckable(@radio) if $self->{uncheckable};
  (wantarray) ? @radio : join($self->{separator}, @radio);
}

sub buttons {shift->BUTTONS(0,'',@_)}
sub named_buttons {shift->BUTTONS(0,@_)}

sub ans_rule {shift->BUTTONS(0,'',@_)}
sub named_ans_rule {shift->BUTTONS(0,@_)}
sub named_ans_rule_extension {shift->BUTTONS(1,@_)}

sub cmp_postprocess {
  my $self = shift; my $ans = shift;
  my $text = $self->labelText($ans->{student_value}->value);
  $ans->{preview_text_string} = $ans->{student_ans} = $text;
  $ans->{preview_latex_string} = "\\hbox{$text}";
}

1;
