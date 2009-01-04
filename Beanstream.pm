package Business::OnlinePayment::Beanstream;

use strict;
use Business::OnlinePayment;
use Net::SSLeay qw/make_form post_https/;
use vars qw/@ISA $VERSION @EXPORT @EXPORT_OK/;

@ISA=qw(Exporter AutoLoader Business::OnlinePayment);
@EXPORT=qw();
@EXPORT_OK=qw();
$VERSION='0.01';

sub set_defaults{
  my $self = shift;
  $self->server('www.beanstream.com');
  $self->port('443');
  $self->path('/scripts/process_transaction.asp');
}

sub map_fields{
  my $self = shift;
  my %content = $self->content();

  my %actions = ( 'normal authorization' => 'P', 
                  'authorization only'   => 'PA',
                );
  $content{action} = $actions{lc $content{action}} || $content{action};
  
  $self->content(%content);
}

sub remap_fields{
  my ($self,%map) = @_;
  my %content = $self->content();
  for (keys %map){ $content{$map{$_}} = $content{$_} || '' }
  $self->content(%content);
}

sub get_fields{
  my ($self,@fields) = @_;
  my %content = $self->content();
  my %new = ();

  for (@fields){ $new{$_} = $content{$_} || '' }

  return %new;
}
  

sub submit{
  my $self = shift;
 
  $self->map_fields();
  $self->remap_fields(
    login          => 'merchant_id',
    action         => 'trnType',
    description    => 'trnComments',
    amount         => 'trnAmount',
    invoice_number => 'trnOrderNumber',
    owner          => 'trnCardOwner',
    name           => 'ordName',
    address        => 'ordAddress1',
    city           => 'ordCity',
    state          => 'ordProvince',
    zip            => 'ordPostalCode',
    country        => 'ordCountry',
    phone          => 'ordPhoneNumber',
    email          => 'ordEmailAddress',
    card_number    => 'trnCardNumber',
    exp_date       => 'trnExpYear',
  );

  $self->required_fields( qw/login amount invoice_number name address city 
                             state zip country phone email card_number 
                             exp_date owner/ );
  
  # We should prepare some fields to posting, for instance ordAddress1 should be cutted and trnExpYear 
  # should be separated to trnExpMonth and trnExpYear
  
  my %content=$self->content();
  my $address = $content{ordAddress1};
  ($content{ordAddress1}, $content{ordAddress2}) = unpack 'A32 A*', $address;
  
  my $date = $content{trnExpYear};
  ($content{trnExpMonth},$content{trnExpYear}) = ($date =~/\//)? 
                                                  split /\//,$date: 
                                                  unpack 'A2 A2',$date;
  
  $self->content(%content);
  
  # Now we are ready to post request
  
  my %post_data = $self->get_fields( qw/merchant_id trnType trnComments 
                                        trnAmount trnOrderNumber trnCardNumber 
                                        trnExpYear trnExpMonth trnCardOwner 
                                        ordName ordAddress1 ordCity ordProvince
                                        ordPostalCode ordCountry ordPhoneNumber
                                        ordEmailAddress/ );
  $post_data{errorPage} = 'www.yahoo.com'; 
  my $pd = make_form(%post_data);
  my ($page,$server_response,%headers) = post_https( $self->server(),
                                                     $self->port(),
                                                     $self->path(),
                                                     '',
                                                     $pd,
                                                   );
  $self->response_code($server_response);
  $self->response_headers(%headers);
  
  # Handling server response
  
  if ($server_response =~/200 OK/){
    
    $self->is_success(0);
    $self->error_message($page);
    $self->server_response($page);
    
  }elsif ($server_response =~/30\d /){
    
    $headers{LOCATION} =~s/\+/ /g;
    $headers{LOCATION} =~s/%([\dA-Fa-f]{2})/chr(hex($1))/ge;
    $headers{LOCATION} =~s/^[^?]+\?//;
    $self->server_response($headers{LOCATION});
    my %fields; 
    for (split /&/, $headers{LOCATION}){
      my ($key,$value) = split '=',$_;
      $fields{$key} = $value;
    }
    
    if ($fields{errorMessage}){
      $self->is_success(0);
      $self->error_message($fields{errorMessage}.$fields{errorFields});
    }elsif ($fields{messageId} =~/^[129]$/){
      $self->is_success(1);
      $self->result_code($fields{messageId});
      $self->authorization($fields{messageText});
    }else {
      $self->is_success(0);
      $self->result_code($fields{messageId});
      $self->error_message($fields{messageText});
    }
    
  }
}

sub response_headers{
  my ($self,%headers) = @_;
  $self->{headers} = join "\n", map{"$_: $headers{$_}"} keys %headers 
                                                        if %headers;
  $self->{headers};
}

sub response_code{
  my ($self,$code) = @_;
  $self->{code} = $code if $code;
  $self->{code};
}

###
# That's all
#
1;

__END__

=head1 NAME 

Business::OnlinePayment::Beanstream - Beanstream backend for Business::OnlinePayment

=head1 SYNOPSYS

  use Business::OnlinePayment;
  
  my $tr = Business::OnlinePayment->new('Beanstream');
  $tr->content(
    login          => '100200000',
    action         => 'Normal Authorization',
    amount         => '1.99',
    invoice_number => '56647',
    owner          => 'John Doe',
    card_number    => '312312312312345',
    exp_date       => '0505',
    name           => 'Sam Shopper',
    address        => '123 Any Street',
    city           => 'Los Angeles',
    state          => 'CA',
    zip            => '23555',
    country        => 'US',
    phone          => '123-4567',
    email          => 'Sam@shopper.com',
  );
  $tr->submit;

  if ($tr->is_success){
    print "Card processed successfully: ".$tr->authorization."\n";
  }else{
    print "Card processing was failed: ".$tr->error_message."\n";
  }

=head1 DESCRIPTION

This module allows you to link any e-commerce order processing system directly to Beanstream transaction server (http://www.beanstream.com). All transaction fields are submitted via GET or POST to the secure transaction server at the following URL: https://www.beanstream.com/scripts/process_transaction.asp. The following fields are required:

=over 4

=item login - merchant login (Beanstream-assigned nine digit identification number)

=item action - type of transaction (Normal Authorization, Authorization Only)

=item amount - total order amount

=item invoice_number - the order number of the shopper's purchase

=item owner - name of the card owner

=item card_number - number of the credit card

=item exp_date - expiration date formated as 'mmyy' or 'mm/yy'

=item name - name of the billing person

=item address - billing address

=item city - billing address city

=item state - billing address state/province

=item zip - billing address zip/postal code

=item country - billing address country

=item phone - billing contacts phone

=item email - billing contact's email

=back

Beanstream supports the following credit card:

=over 4

=item - VISA

=item - MasterCard

=item - American Express Card

=item - Discover Card

=item - JCB

=item - Diners

=back

Currently you may process only two types of transaction, namely 'Normal Authorization' (Purchase) and 'Authorization Only' (Pre-Auth).

For detailed information about methods see L<Business::OnlinePayment>

=head1 SEE ALSO

L<Business::OnlinePayment>

=cut
