use Mojo::Base -strict;
use Data::Dumper;
use Mojo::Pg;
use YAML::Tiny;

my $filename = shift;

my $yaml = YAML::Tiny->read($ENV{GDB_CONFIG}) or die "Cant read config!";

my $config = $yaml->[0];

my $pg = Mojo::Pg->new($config->{pg}->{uri}) or die "Cant connect to DB";
my $db = $pg->db;
open my $file, "<$filename" or die "Error::$!";

say "Parse file [ $filename ] start";

my $chunk_size = 500;

my ( @messages, @log );

my ( $msg_counter, $log_counter ) = (0,0);

while( my $str = <$file> ){
    next if ( !$str || $str =~ /^\s+$/ );
    chomp($str);

    my @fields = split(/ /, $str);

    my $created_timestamp = qq{$fields[0] $fields[1]};

    if ( $fields[3] eq '<=' ){
        $msg_counter++;

        my $id = ( $str =~ /id=(.+)(?:\s|$)/ )[0]; # ??? Может надо было взять цифровой id? В задаче об этом не было

        unless (defined $id){
            warn "ERROR:: STRING HAS NO id, SKIPPING : [$str]\n"; # ??? Может надо было строки объеденять по int_id?
            next;
        }

        push @messages, {
            created => $created_timestamp,
            int_id  => $fields[2],
            id      => $id, 
            str     => join(' ', splice(@fields, 2 ) )
            };

        if ( $msg_counter >= $chunk_size ){
            $msg_counter = 0;

            save_chunk('message', \@messages);

            @messages = ();
        }
    }
    else {
        $log_counter++;

        push @log, {
            created => $created_timestamp,
            int_id  => $fields[2],
            str     => join(' ', splice(@fields, 2 ) ),
            address => ( $str =~ /([a-z0-9\_\-]+\@[a-z0-9\-]+\.[a-z]{2,3})/i )[0] // undef,
            };

        if ( $log_counter >= $chunk_size ){
            $log_counter = 0;

            save_chunk('log', \@log);

            @log = ();
        }
    }

}

close $file;

save_chunk('message', \@messages) if scalar(@messages);
save_chunk('log', \@log) if scalar(@log);


sub save_chunk {
    my ($table, $chunk) = @_;

    state $fields = {
        message => [ qw(created int_id id str) ],
        log     => [ qw(created int_id str address) ],
        };

    state $inserted = { log => 0, message => 0 };

    my $sql = qq{INSERT INTO ${table}(@{[ join(",", @{ $fields->{$table} } ) ]}) VALUES
                 @{[ join(",\n", map { "(?,?,?,?)" } @$chunk ) ]}
                 @{[ $table eq 'message' ? 'ON CONFLICT(id) DO NOTHING' : '' ]}
         };

    my @values;

    for my $item ( @$chunk ){
        push @values, ( map { $item->{$_} } @{ $fields->{$table} } )
    }

    eval {
        $db->query($sql, @values);
    } or do {
        warn "ERROR:: Can't insert $table chunk, error: $@\nchnunk @{[ Dumper($chunk) ]}\n";
    };

    say "Insert $table chunk @{[ ++$inserted->{$table} ]} ok";
}

say "Parse file [ $filename ] end";
