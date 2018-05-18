#!/usr/bin/ruby
#
# mqtt2serial.rb
# 
# Usage:
#   $ gem install mqtt serialport
#   $ git clone https://github.com/yoggy/mqtt-serial.git
#   $ cd mqtt-serial
#   $ ./mqtt2serial.rb
#   
#   usage : ./mqtt2serial.rb host port subscribe_topic serialport bps
#
#   example :
#       $ ./mqtt2serial.rb localhost 1883 topic/recv /dev/ttyUSB0 9600
#
#   $ ./mqtt2serial.rb iot.eclipse.org 1883 serial2mqtt/recv /dev/ttyUSB0 115200
#
# License:
#   Copyright (c) 2018 yoggy <yoggy0@gmail.com>
#   Released under the MIT license
#   http://opensource.org/licenses/mit-license.php;
#

require 'serialport'
require 'mqtt'
require 'pp'
require 'ostruct'
require 'logger'

$stdout.sync = true
$log = Logger.new(STDOUT)
$conf = OpenStruct.new

def usage
  puts <<-EOS
usage : #{$0} host port subscribe_topic serialport bps

example :
    $ #{$0} localhost 1883 topic/recv /dev/ttyUSB0 9600
EOS
  exit(1)
end

def read_loop
  $log.info "open : serialport=#{$conf.dev}, bps=#{$conf.bps}"
  sp = SerialPort.new($conf.dev, $conf.bps, 8, 1, 0)
  buf = ""

  MQTT::Client.connect(:host=>$conf.host, :port=>$conf.port) do |mqtt|
    $log.info "mqtt connected! : host=#{$conf.host}, port=#{$conf.port}"

    mqtt.subscribe($conf.topic)
    $log.info "mqtt subscribe : topic=#{$conf.topic}"

    mqtt.get do |topic, msg|
      $log.info "mqtt receiveed message : topic=#{topic}, msg=#{msg.pretty_inspect}"
      sp.write(msg)
      sp.flush
    end
  end
end

if __FILE__ == $0 
  usage if ARGV.size != 5

  $conf.host  = ARGV[0]
  $conf.port  = ARGV[1].to_i
  $conf.topic = ARGV[2]
  $conf.dev   = ARGV[3]
  $conf.bps   = ARGV[4].to_i

  $log.info "conf=" + $conf.pretty_inspect

  loop do
    begin
      read_loop
    rescue Exception => e
      $log.error e.message
      $log.error e.backtrace
      $log.info "restarting after 10 seconds..."
      sleep 10
    end
  end
end

