require "json"
require "net/http"
require "optparse"

# Set some reasonable defaults.
OPTIONS = {
    debug: false,
    http_method: "GET",
    interval: 10,
    no_header: false,
    outfile: STDOUT,
    running_time: 300,
    silent: false,
    verbose: false
}

OptionParser.new do |parser|
    parser.banner = "Usage: responder.rb [options]"
    parser.on("-d", "--debug") { |o| OPTIONS[:debug] = true }
    parser.on("-i", "--interval SECONDS", "Defaults to 10 seconds.") { |o| OPTIONS[:interval] = o.to_i }
    parser.on("-m", "--http_method METHOD", "Supports either GET or HEAD.  Defaults to GET.") { |o| OPTIONS[:http_method] = o.upcase }
    parser.on("--no-header", "Don't print the header.") { |o| OPTIONS[:no_header] = true }
    parser.on("-o", "--outfile FILE") { |o| OPTIONS[:outfile] = o }
    parser.on("-s", "--silent") { |o| OPTIONS[:silent] = true }
    parser.on("-t", "--running_time SECONDS", "Total time of test.  Defaults to 5 minutes.") { |o| OPTIONS[:running_time] = o.to_i }
    parser.on("-v", "--verbose", "Print every response time in ms.") { |o| OPTIONS[:verbose] = true }
    parser.on("-h", "--help") { puts parser; exit }
end.parse!

if OPTIONS[:debug]
    puts JSON.pretty_generate OPTIONS
end

HOSTNAME = "gitlab.com"
PORT = "443"
NET_HTTP_ERRORS = [
    EOFError,
    Errno::EINVAL,
    Errno::ECONNRESET,
    Net::HTTPBadResponse,
    Net::HTTPHeaderSyntaxError,
    Net::ProtocolError,
    Net::ReadTimeout,
    SocketError
]
RESPONSE_TIMES = []
@max = -1.0/0.0
@min = +1.0/0.0
@number_of_requests = 0

def dump_json
    h = {
        "domain": HOSTNAME,
        "port": PORT,
        "running_time": OPTIONS[:running_time],
        "response_times": RESPONSE_TIMES,
        "maximum_response_time": @max,
        "minimum_response_time": @min
    }
    puts JSON.pretty_generate h
end

def print_header
    printf "[INFO] Testing endpoint `%s:%s`.\n", HOSTNAME, PORT
    printf "[INFO] HTTP method is %s.\n", OPTIONS[:http_method]
    printf "[INFO] Calling `run_interval` every %s seconds.\n", OPTIONS[:interval]
    printf "[INFO] Total running time is %s seconds.\n", OPTIONS[:running_time]
end

def print_results
    puts "\n==============="
    puts "RESPONSE TIMES:"
    puts "==============="
    printf "Average: %.3f\n", RESPONSE_TIMES.reduce(0, :+) / @number_of_requests
    printf "Maximum: %.3f\n", @max
    printf "Minimum: %.3f\n", @min
end

def run_interval seconds
    n = 0
    loop do
        begin
            yield @number_of_requests
            sleep seconds
            n += seconds
            @number_of_requests += 1
            break if n >= OPTIONS[:running_time]
        rescue Interrupt
            # Handle SIGINT (Ctrl-C).
            dump_json
            exit
        end
    end
end

def traceroute n
    begin
        start_time = Time.now
        http = Net::HTTP.new(HOSTNAME, PORT)
        http.read_timeout = 10
        http.send(OPTIONS[:http_method].downcase, "/")
        end_time = (Time.now - start_time) * 1000

        if OPTIONS[:outfile] == STDOUT
            res = sprintf "%.3f", end_time
            if not OPTIONS[:silent]
                n += 1
                if OPTIONS[:verbose]
                    printf "%d..%.3fms\n", n, res
                else
                    printf "%d..", n
                end
            end

            RESPONSE_TIMES.push(end_time)

            if end_time > @max
                @max = end_time
            end
            if end_time < @min
                @min = end_time
            end
        end
    rescue *NET_HTTP_ERRORS => error
        puts error
    end
end

if not OPTIONS[:silent] and not OPTIONS[:no_header]
    print_header
end

run_interval OPTIONS[:interval] do |n|
    thread = Thread.new { traceroute n }
    thread.join
end

if not OPTIONS[:silent]
    print_results
else
    dump_json
end

