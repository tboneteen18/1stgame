require 'socket'
require 'thread'
require 'json'

$positions = Hash.new

$id = 0
$semaphore = Mutex.new              # Get sockets from stdlib

server = TCPServer.open(2000)   # Socket to listen on port 2000
loop {                          # Servers run forever
  Thread.start(server.accept) do |client|
    my_id = 0
    begin
      while command = client.gets  # Read lines from the socket
        if command == nil then
          next
        end
        if command.start_with?("i") then
          puts "Got a new connection from a client"
          $semaphore.synchronize {   # access shared resource
            client.puts "#{$id}"
            my_id = $id
            $id += 1
          }
        elsif command.start_with?('{')
          pl = JSON.parse(command)
          $positions[pl["id"]] = [pl["x"], pl["y"], pl["rot"]]
          client.puts $positions.to_json
        end
      end
    rescue Exception => e
      # Displays Error Message
      puts "#{ e } (#{ e.class })"
    ensure
      $positions.delete("#{my_id}")
      client.close
      puts "ensure: Closing client connection"
    end
  end
}
