package FusionInventory::Agent::HTTP::Client;

use strict;
use warnings;

use English qw(-no_match_vars);
use LWP::UserAgent;
use UNIVERSAL::require;

use FusionInventory::Agent::Logger;

sub new {
    my ($class, %params) = @_;

    die "non-existing certificate file $params{ca_cert_file}"
        if $params{ca_cert_file} && ! -f $params{ca_cert_file};

    die "non-existing certificate directory $params{ca_cert_dir}"
        if $params{ca_cert_dir} && ! -d $params{ca_cert_dir};

    my $self = {
        logger         => $params{logger} ||
                          FusionInventory::Agent::Logger->new(),
        user           => $params{user},
        password       => $params{password},
        ca_cert_file   => $params{ca_cert_file},
        ca_cert_dir    => $params{ca_cert_dir},
        no_ssl_check   => $params{no_ssl_check},
        timeout        => $params{timeout} || 180
    };
    bless $self, $class;

    # create user agent
    $self->{ua} = LWP::UserAgent->new(keep_alive => 1, requests_redirectable => ['POST', 'GET', 'HEAD']);

    if ($params{proxy}) {
        $self->{ua}->proxy(['http', 'https'], $params{proxy});
    }  else {
        $self->{ua}->env_proxy;
    }

    if ($LWP::VERSION > 6) {
        # LWP6 default behavior is to check the SSL hostname
        if ($params{'no_ssl_check'}) {
            $self->{ua}->ssl_opts(verify_hostname => 0);
        }
        if ($params{'ca_cert_file'}) {
            $self->{ua}->ssl_opts(SSL_ca_file => $params{'ca_cert_file'});
        }
        if ($params{'ca_cert_dir'}) {
            $self->{ua}->ssl_opts(SSL_ca_path => $params{'ca_cert_dir'});
        }
    }

    $self->{ua}->agent($FusionInventory::Agent::AGENT_STRING);
    $self->{ua}->timeout($params{timeout});

    return $self;
}

# This is not needed with LWP>6, the default behavior is fine now.
# http://stackoverflow.com/questions/74358/validate-server-certificate-with-lwp
sub _turnSSLCheckOn {
    my ($self) = @_;

    eval {
        require Crypt::SSLeay;
    };
    if ($EVAL_ERROR) {
        die "failed to load Crypt::SSLeay, unable to validate SSL certificates";
    }

    SWITCH: {
        if ($self->{ca_cert_file}) {
            $ENV{HTTPS_CA_FILE} = $self->{ca_cert_file};
            $ENV{PERL_LWP_SSL_CA_FILE} = $self->{ca_cert_file};
            last SWITCH;
        }
        if ($self->{ca_cert_dir}) {
            $ENV{HTTPS_CA_DIR} = $self->{ca_cert_dir};
            $ENV{PERL_LWP_SSL_CA_PATH} = $self->{ca_cert_dir};
            last SWITCH;
        }
        die
            "neither certificate file or certificate directory given, unable " .
            "to validate SSL certificates";
    }
}

sub _getCertificatePattern {
    my ($hostname) = @_;

    # Accept SSL cert will hostname with wild-card
    # http://forge.fusioninventory.org/issues/542
    $hostname =~ s/^([^\.]+)/($1|\\*)/;
    # protect metacharacters, as pattern will be evaluated as a regex
    $hostname =~ s/\./\\./g;

    return "CN=$hostname(\$|\/)";
}

sub getStore {
    my ($self, %params) = @_;

    my $source = $params{source};
    my $noProxy = $params{noProxy};

    my $response;
    eval {
        if ($^O =~ /^MSWin/ && $source =~ /^https:/g) {
            alarm $self->{timeout};
        }

        my $request = HTTP::Request->new(GET => $source);
        $response = $self->{ua}->request($request);
        alarm 0;
    };

    return $response->code;

}

sub get {
    my ($self, %params) = @_;

    my $source = $params{source};
    my $noProxy = $params{noProxy};

    my $response = $self->{ua}->get($source);

    return $response->decoded_content if $response->is_success;

    return;
}

sub isSuccess {
    my ($self, %params) = @_;

    my $code = $params{code};

    return is_success($code);
}

1;
__END__

=head1 NAME

FusionInventory::Agent::HTTP::Client - An abstract HTTP client

=head1 DESCRIPTION

This is an abstract class for HTTP clients. It can send messages through HTTP
or HTTPS, directly or through a proxy, and validate SSL certificates.

=head1 METHODS

=head2 new(%params)

The constructor. The following parameters are allowed, as keys of the %params
hash:

=over

=item I<logger>

the logger object to use (default: a new stderr logger)

=item I<proxy>

the URL of an HTTP proxy

=item I<user>

the user for HTTP authentication

=item I<password>

the password for HTTP authentication

=item I<no_ssl_check>

a flag allowing to ignore untrusted server certificates (default: false)

=item I<ca_cert_file>

the file containing trusted certificates

=item I<ca_cert_dir>

the directory containing trusted certificates

=back

=head2 getStore(%params)

Acts like LWP::Simple::getstore.

        my $rc = $client->getStore({
                source => 'http://www.FusionInventory.org/',
                target => '/tmp/fusioinventory.html'
                noProxy => 0
            });

$rc, can be read by isSuccess()

=head2 get(%params)

        my $content = $client->get(
                source => 'http://www.FusionInventory.org/',
                timeout => 15,
                noProxy => 0
            );

Act like LWP::Simple::get, return the HTTP content of the URL in 'source'.
The timeout is optional

=head2 isSuccess(%params)

Wrapper for LWP::is_success;

        die unless $client->isSuccess({ code => $rc });
