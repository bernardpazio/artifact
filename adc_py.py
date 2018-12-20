import base64


class InvalidDeckException(Exception):
    def __init__(self, deck, *args, **kwargs):
        super(InvalidDeckException, self).__init__(*args, **kwargs)
        self.deck = deck


class DeckEncodingException(Exception):
    pass


class DeckDecodingException(Exception):
    def __init__(self, deck_code, *args, **kwargs):
        super(DeckDecodingException, self).__init__(*args, **kwargs)
        self.deck_code = deck_code


class DeckEncoder:
    version = 2
    prefix = 'ADC'
    header_size = 3

    @staticmethod
    def encode(deck: dict):
        if not DeckEncoder._is_valid_deck(deck):
            raise InvalidDeckException(deck)

        heroes = sorted(deck['heroes'], key=lambda c: c['card_id'])
        cards = sorted(deck['cards'], key=lambda c: c['card_id'])

        buffer = bytearray()

        version = DeckEncoder.version << 4 | DeckEncoder._extract_bits_with_carry(len(heroes), 3)
        buffer.append(version)

        dummy_checksum = 0
        checksum_position = len(buffer)

        buffer.append(dummy_checksum)

        name = bytes(deck.get('name', ''), 'utf-8')
        if len(name) > 63:
            name = name[:63]
        buffer.append(len(name))

        DeckEncoder._add_remaining_to_buffer(len(heroes), 3, buffer)

        last_card_id = 0
        for hero in heroes:
            DeckEncoder._add_card_to_buffer(hero['turn'], hero['card_id'] - last_card_id, buffer)
            last_card_id = hero['card_id']

        last_card_id = 0
        for card in cards:
            DeckEncoder._add_card_to_buffer(card['count'], card['card_id'] - last_card_id, buffer)
            last_card_id = card['card_id']

        full_checksum = DeckEncoder._compute_checksum(bytes(buffer[DeckEncoder.header_size:]))
        small_checksum = full_checksum & 0x0FF

        buffer[checksum_position] = small_checksum

        buffer += name

        deck_code = DeckEncoder.prefix + base64.b64encode(buffer).decode('utf-8')
        deck_code = deck_code.replace('/', '-').replace('=', '_')

        return deck_code

    @staticmethod
    def _compute_checksum(bytes_buffer: bytes):
        checksum = 0
        for b in bytes_buffer:
            checksum += b
        return checksum

    @staticmethod
    def _add_card_to_buffer(count: int, value: int, buffer: bytearray):
        max_count_bits = 0x03
        extended_count = (count - 1) >= max_count_bits

        first_byte_count = max_count_bits if extended_count else (count - 1)
        first_byte = first_byte_count << 6
        first_byte |= DeckEncoder._extract_bits_with_carry(value, 5)

        buffer.append(first_byte)

        DeckEncoder._add_remaining_to_buffer(value, 5, buffer)

        if extended_count:
            DeckEncoder._add_remaining_to_buffer(count, 0, buffer)

    @staticmethod
    def _add_remaining_to_buffer(value: int, pos: int, buffer: bytearray):
        value >>= pos
        while value > 0:
            next_byte = DeckEncoder._extract_bits_with_carry(value, 7)
            buffer.append(next_byte)

            value >>= 7

    @staticmethod
    def _extract_bits_with_carry(value: int, num_bits: int):
        limit = 1 << num_bits
        result = value & (limit - 1)
        if value >= limit:
            result |= limit
        return result

    @staticmethod
    def _is_valid_deck(deck: dict):
        if 'heroes' not in deck or 'cards' not in deck:
            return False

        heroes = deck['heroes']
        cards = deck['cards']

        if len(heroes) != 5:
            return False

        turns = [0, 0, 0]
        for hero in heroes:
            if 'turn' not in hero or 'card_id' not in hero:
                return False

            turn = hero['turn'] - 1
            if turn < 0 or turn > 2:
                return False

            turns[turn] += 1

        if turns[0] != 3 or turns[1] != 1 or turns[2] != 1:
            return False

        for card in cards:
            if 'count' not in card or 'card_id' not in card:
                return False

        return True


class DeckDecoder:
    version = 2
    prefix = 'ADC'

    @staticmethod
    def decode(deck_code: str):
        deck_code_prefix = deck_code[:len(DeckDecoder.prefix)]
        if deck_code_prefix != DeckDecoder.prefix:
            msg = f'Invalid deck code prefix: Got ({deck_code_prefix}) Expected ({DeckDecoder.prefix})'
            raise DeckDecodingException(deck_code, msg)

        deck_code_no_prefix = deck_code[len(DeckDecoder.prefix):].replace('-', '/').replace('_', '=')
        deck_code_bytes = base64.decodebytes(bytes(deck_code_no_prefix, 'utf-8'))

        current_byte = 0
        total_bytes = len(deck_code_bytes)

        version_and_heroes = deck_code_bytes[current_byte]
        current_byte += 1
        version = version_and_heroes >> 4

        if version != DeckDecoder.version and version != 1:
            msg = f'Deck code version ({version}) and decoder version ({DeckDecoder.version}) mismatch'
            raise DeckDecodingException(deck_code, msg)

        checksum = deck_code_bytes[current_byte]
        current_byte += 1

        string_length = 0
        if version > 1:
            string_length = deck_code_bytes[current_byte]
            current_byte += 1
        total_card_bytes = total_bytes - string_length

        computed_checksum = DeckEncoder._compute_checksum(deck_code_bytes[current_byte:total_card_bytes]) & 0x0FF
        if checksum != computed_checksum:
            msg = f'Checksum in deck code ({checksum}) does not match computed checksum ({computed_checksum})'
            raise DeckDecodingException(deck_code, msg)

        num_heroes, current_byte = DeckDecoder._read_int(version_and_heroes, 3, deck_code_bytes, current_byte,
                                                         total_card_bytes)

        heroes = []
        last_card_id = 0
        for i in range(num_heroes):
            card_id, turn, current_byte = DeckDecoder._read_serialized_card(deck_code_bytes, current_byte,
                                                                            total_card_bytes, last_card_id)
            last_card_id = card_id
            heroes.append({'card_id': card_id, 'turn': turn})

        cards = []
        last_card_id = 0
        while current_byte < total_card_bytes:
            card_id, count, current_byte = DeckDecoder._read_serialized_card(deck_code_bytes, current_byte,
                                                                             total_card_bytes, last_card_id)
            last_card_id = card_id
            cards.append({'card_id': card_id, 'count': count})

        name = ''
        if current_byte <= total_bytes:
            name = deck_code_bytes[-string_length:].decode('utf-8')

        return {'heroes': heroes, 'cards': cards, 'name': name}

    @staticmethod
    def _read_serialized_card(data, start, end, last_card_id):
        if start > end:
            raise Exception()

        header = data[start]
        start += 1
        extended_count = (header >> 6) == 0x03

        card_delta, start = DeckDecoder._read_int(header, 5, data, start, end)
        card_id = last_card_id + card_delta

        if extended_count:
            count, start = DeckDecoder._read_int(0, 0, data, start, end)
        else:
            count = (header >> 6) + 1

        return card_id, count, start

    @staticmethod
    def _read_int(base_value, base_bits, data, start, end):
        out = 0
        delta_shift = 0
        out, cont = DeckDecoder._read_bits_chunk(base_value, base_bits, delta_shift, out)
        if base_bits == 0 or cont:
            delta_shift += base_bits

            while True:
                if start > end:
                    raise Exception()

                next_byte = data[start]
                start += 1
                out, cont = DeckDecoder._read_bits_chunk(next_byte, 7, delta_shift, out)
                if not cont:
                    break

                delta_shift += 7

        return out, start

    @staticmethod
    def _read_bits_chunk(chunk, num_bits, current_shift, out):
        continue_bit = 1 << num_bits
        new_bites = chunk & (continue_bit - 1)
        out |= new_bites << current_shift

        return out, (chunk & continue_bit) != 0
