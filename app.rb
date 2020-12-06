require 'json'
require 'date'
require 'csv'

def main
  json = read_from_json(ARGV.first)

  CSV.open('output.csv', 'ab') do |csv|
    csv << ['date', 'uuid', 'was i maker?', 'taker coin', 'maker coin', 'taker amount', 'maker amount', 'taker address', 'txid', 'maker address', 'txid']
  end

  json.each do |swap|
    finished = swap['events'].any? { |item| item['event']['type'] == 'TakerPaymentSpent' } &&
               swap['events'].any? { |item| item['event']['type'] == 'MakerPaymentSpent' }

    next unless finished

    date, i_am_maker, taker_coin, maker_coin, taker_amount, maker_amount, maker_address, maker_spent_hash, taker_address, taker_spent_hash = ''
    uuid = swap['uuid']

    swap['events'].each do |event|
      date = DateTime.strptime(event['timestamp'].to_s, '%Q')

      if event['event']['type'] == 'Started'
        i_am_maker = event['event']['data']['maker'] == 'ae3643a5a5bfeb9b133689b4d393f29d614451a8130d1402bc037240a3595cbe'

        maker_coin = event['event']['data']['maker_coin']
        taker_coin = event['event']['data']['taker_coin']
        maker_amount = event['event']['data']['maker_amount']
        taker_amount = event['event']['data']['taker_amount']
      end

      if i_am_maker
        if event['event']['type'] == 'MakerPaymentReceived'
          maker_address = event['event']['data']['from'].first
          maker_spent_hash = event['event']['data']['tx_hash']
        end

        if event['event']['type'] == 'TakerPaymentSpent'
          taker_address = event['event']['data']['transaction']['to'].first
          taker_spent_hash = event['event']['data']['transaction']['tx_hash']
        end
      else
        if event['event']['type'] == 'MakerPaymentSpent'
          maker_address = event['event']['data']['to'].first
          maker_spent_hash = event['event']['data']['tx_hash']
        end

        if event['event']['type'] == 'TakerPaymentSent'
          taker_address = event['event']['data']['from'].first
          taker_spent_hash = event['event']['data']['tx_hash']
        end
      end
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

def read_from_json(file_name)
  file = File.read(file_name)
  hash = []
  file.each_line do |line|
    if line == "\r\n"
      next
    end

    hash << JSON.parse(line)
  end

  hash
end

main