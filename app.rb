require 'json'
require 'date'
require 'csv'

def main
  json = read_from_json(ARGV.first)

  CSV.open('output.csv', 'ab') do |csv|
    csv << ['date', 'uuid', 'was i maker?', 'taker coin', 'maker coin', 'taker amount', 'maker amount', 'taker address', 'txid', 'maker address', 'txid']
  end

  my_addresses = []
  File.read('addresses.txt').each_line do |line|
    my_addresses << line.strip
  end

  excluded_coins = []
  File.read('excluded_coins.txt').each_line do |line|
    excluded_coins << line.strip
  end

  json.each do |swap|
    finished = swap['events'].any? { |item| item['event']['type'] == 'TakerPaymentSpent' } ||
               swap['events'].any? { |item| item['event']['type'] == 'MakerPaymentSpent' }

    next unless finished

    date, taker_coin, maker_coin, taker_amount, maker_amount, maker_address, maker_spent_hash, taker_address, taker_spent_hash = ''
    uuid = swap['uuid']

    i_am_maker = swap['events'].any? { |item| (item['event']['type'] == 'MakerPaymentReceived' && (my_addresses.include? item['event']['data']['from'].first)) ||
                                              (item['event']['type'] == 'MakerPaymentSent' && (my_addresses.include? item['event']['data']['from'].first))}

    catch :excluded_coin do
      swap['events'].each do |event|
        if event['event']['type'] == 'Started'
          maker_coin = event['event']['data']['maker_coin']
          taker_coin = event['event']['data']['taker_coin']
          if (excluded_coins.include? maker_coin) || (excluded_coins.include? taker_coin)
            throw :excluded_coin
          end
          maker_amount = event['event']['data']['maker_amount']
          taker_amount = event['event']['data']['taker_amount']
        end

        if i_am_maker
          if event['event']['type'] == 'MakerPaymentReceived' || event['event']['type'] == 'MakerPaymentSent'
            maker_address = event['event']['data']['from'].first
            maker_spent_hash = event['event']['data']['tx_hash']
          end

          if event['event']['type'] == 'TakerPaymentSpent'
            begin
              taker_address = event['event']['data']['transaction']['to'].first
              taker_spent_hash = event['event']['data']['transaction']['tx_hash']
            rescue NoMethodError
              taker_address = event['event']['data']['to'].first
              taker_spent_hash = event['event']['data']['tx_hash']
            end
          end
        else
          if event['event']['type'] == 'MakerPaymentSpent'
            maker_address = event['event']['data']['to'].first
            maker_spent_hash = event['event']['data']['tx_hash']
          end

          if event['event']['type'] == 'TakerPaymentSent' || event['event']['type'] == 'TakerPaymentReceived'
            taker_address = event['event']['data']['from'].first
            taker_spent_hash = event['event']['data']['tx_hash']
          end
        end

        date = DateTime.strptime(event['timestamp'].to_s, '%Q')
      end

      CSV.open('output.csv', 'ab') do |csv|
        csv << [
          date,
          uuid,
          i_am_maker ? 'maker' : 'taker',
          taker_coin,
          maker_coin,
          taker_amount,
          maker_amount,
          taker_address,
          taker_spent_hash,
          maker_address,
          maker_spent_hash
        ]
      end
    end
  end
end

def read_from_json(file_name)
  file = File.read(file_name)
  hash = []
  file.each_line do |line|
    begin
      hash << JSON.parse(line)
    rescue StandardError
      puts 'Error: could not parse line: ' + line unless line == "\n" || line == "\r\n"
    end
  end

  hash
end

main
