# @TEST-SERIALIZE: comm
#
# @TEST-EXEC: btest-bg-run sender bro -b --pseudo-realtime %INPUT ../sender.bro
# @TEST-EXEC: sleep 1
# @TEST-EXEC: btest-bg-run receiver bro -b --pseudo-realtime %INPUT ../receiver.bro
# @TEST-EXEC: sleep 1
# @TEST-EXEC: btest-bg-wait 15
# @TEST-EXEC: btest-diff sender/test.log
# @TEST-EXEC: btest-diff sender/test.failure.log
# @TEST-EXEC: btest-diff sender/test.success.log
# @TEST-EXEC: ( cd sender && for i in *.log; do cat $i | $SCRIPTS/diff-remove-timestamps >c.$i; done )
# @TEST-EXEC: ( cd receiver && for i in *.log; do cat $i | $SCRIPTS/diff-remove-timestamps >c.$i; done )
# @TEST-EXEC: cmp receiver/c.test.log sender/c.test.log
# @TEST-EXEC: cmp receiver/c.test.failure.log sender/c.test.failure.log
# @TEST-EXEC: cmp receiver/c.test.success.log sender/c.test.success.log

# This is the common part loaded by both sender and receiver.
module Test;

export {
	# Create a new ID for our log stream
	redef enum Log::ID += { LOG };

	# Define a record with all the columns the log file can have.
	# (I'm using a subset of fields from ssh-ext for demonstration.)
	type Log: record {
		t: time;
		id: conn_id; # Will be rolled out into individual columns.
		status: string &optional;
		country: string &default="unknown";
	} &log;
}

event bro_init() &priority=5
{
	Log::create_stream(Test::LOG, [$columns=Log]);
	Log::add_filter(Test::LOG, [$name="f1", $path="test.success", $pred=function(rec: Log): bool { return rec$status == "success"; }]);
}

#####

@TEST-START-FILE sender.bro

@load frameworks/communication/listen

redef exit_only_after_terminate = T;

module Test;

function fail(rec: Log): bool
	{
	return rec$status != "success";
	}

event Broker::incoming_connection_established(peer_name: string)
	{
	local config: table[string] of string;
	config["tsv"] = "T";
	Log::add_filter(Test::LOG, [$name="f2", $path="test.failure", $pred=fail, $config=config]);

	local cid = [$orig_h=1.2.3.4, $orig_p=1234/tcp, $resp_h=2.3.4.5, $resp_p=80/tcp];

	local r: Log = [$t=network_time(), $id=cid, $status="success"];

	# Log something.
	Log::write(Test::LOG, r);
	Log::write(Test::LOG, [$t=network_time(), $id=cid, $status="failure", $country="US"]);
	Log::write(Test::LOG, [$t=network_time(), $id=cid, $status="failure", $country="UK"]);
	Log::write(Test::LOG, [$t=network_time(), $id=cid, $status="success", $country="BR"]);
	Log::write(Test::LOG, [$t=network_time(), $id=cid, $status="failure", $country="MX"]);
	terminate();
	}

@TEST-END-FILE

@TEST-START-FILE receiver.bro

#####

@load base/frameworks/communication

redef Communication::nodes += {
    ["foo"] = [$host = 127.0.0.1, $connect=T, $request_logs=T]
};

event Broker::outgoing_connection_broken(peer_address: string,
                                        peer_port: port,
                                        peer_name: string)
	{
	terminate();
	}

@TEST-END-FILE
