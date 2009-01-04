use Test;
use strict;
use constant DEBUG => 0;
BEGIN{ plan test=>2 };

use Business::OnlinePayment;

# 1. We will try to connect to beanstream server and post faked data. If server response is OK,
#    then test is succesfully passed.

my $trans = Business::OnlinePayment->new('Beanstream');
$trans->content(
  login          => '100200000',
  action         => 'Normal Authorization',
  amount         => '1.99',
  invoice_number => '56647',
  owner          => 'John Doe',
  card_number    => '312312312312345',
  exp_date       => '05/05',
  name           => 'Sam Shopper',
  address        => '123 Any Street',
  city           => 'Los Angeles',
  state          => 'CA',
  zip            => '23555',
  country        => 'US',
  phone          => '123-4567',
  email          => 'Sam@shopper.com',
  error_page     => 'http://www.yahoo.com',
);

$trans->submit();
print STDERR $trans->error_message(),"\n" if DEBUG; 
ok($trans->response_code()=~/200 OK/);

# 2. We will try to connect to beanstream server and post a correct data. If server response is redirect,
#    then test is succesfully passed.

$trans->content(
  login          => '107900000',
  action         => 'Normal Authorization',
  amount         => '1.99',
  invoice_number => '56647',
  owner          => 'John Doe',
  card_number    => '312312312312345',
  exp_date       => '05/05',
  name           => 'Sam Shopper',
  address        => '123 Any Street',
  city           => 'Los Angeles',
  state          => 'CA',
  zip            => '23555',
  country        => 'US',
  phone          => '123-4567',
  email          => 'Sam@shopper.com',
  error_page     => 'http://www.yahoo.com',
);

$trans->submit();
if (DEBUG){
  if ($trans->is_success){
    print STDERR "\n",$trans->authorization(),"\n"; 
  }else{
    print STDERR "\n",$trans->error_message(),"\n"; 
  }
}
ok($trans->response_code()=~/3\d\d/);

