require 'net/telnet'
require 'mail'
require 'resolv'

module EmailChecker
  SERVER_NOT_OK = "server_not_ok"
  ADDRESS_NOT_OK = "address_not_ok"
  ADDRESS_OK = "address_ok"
  ADDRESS_OK_ACCEPTS_ALL = "address_ok_but_accepts_all"

  def self.get_server email
    domain = Mail::Address.new(email).domain
    resources = []
    Resolv::DNS.open do |dns|
      resources += dns.getresources(domain, Resolv::DNS::Resource::IN::MX)
    end
    resources.sort_by(&:preference).first.exchange.to_s
  end

  def self.check_email email
    server = EmailChecker.get_server(email)

    domain = Mail::Address.new(email).domain

    positive_response_codes = [220, 250, 251]
    negative_response_codes = [252, 421, 450, 451, 452, 500, 501, 502, 503, 504, 521, 530, 550, 551, 552, 553, 554]

    pop = Net::Telnet::new(
        "Host" => server,
        "Port" => 25,
        "Telnetmode" => false,
        "Prompt" => Regexp.new((positive_response_codes + negative_response_codes).map{|c| "(^#{c})"}.join("|"), Regexp::MULTILINE)
    )
    response = nil
    p "HELO john.org..."
    pop.cmd("HELO john.org") { |c| p c ; response = c }
    unless response =~ Regexp.new((positive_response_codes).map{|c| "(^#{c})"}.join("|"), Regexp::MULTILINE)
      pop.close
      return SERVER_NOT_OK
    end
    p "mail from:<john@john.org>..."
    pop.cmd("mail from:<john@john.org>") {|c| p c}

    p "rcpt to:<#{email}>..."
    pop.cmd("rcpt to:<#{email}>") { |c| p c ; response = c }
    unless response =~ Regexp.new((positive_response_codes).map{|c| "(^#{c})"}.join("|"), Regexp::MULTILINE)
      pop.close
      return ADDRESS_NOT_OK
    end

    pop.close
    pop = Net::Telnet::new(
        "Host" => server,
        "Port" => 25,
        "Telnetmode" => false,
        "Prompt" => Regexp.new((positive_response_codes + negative_response_codes).map{|c| "(^#{c})"}.join("|"), Regexp::MULTILINE)
    )
    p "HELO john.org..."
    pop.cmd("HELO john.org") { |c| p c ; response = c }
    unless response =~ Regexp.new((positive_response_codes).map{|c| "(^#{c})"}.join("|"), Regexp::MULTILINE)
      pop.close
      return SERVER_NOT_OK
    end
    p "mail from:<john@john.org>..."
    pop.cmd("mail from:<john@john.org>") {|c| p c}

    p "rcpt to:<fhd7fnks78dkb@#{domain}>..."
    pop.cmd("rcpt to:<fhd7fnks78dkb@#{domain}>") { |c| p c ; response = c }
    if response =~ Regexp.new((positive_response_codes).map{|c| "(^#{c})"}.join("|"), Regexp::MULTILINE)
      pop.close
      return ADDRESS_OK_ACCEPTS_ALL
    else
      pop.close
      return ADDRESS_OK
    end
  end
end