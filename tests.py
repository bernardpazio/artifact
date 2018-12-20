import unittest
from adc import DeckEncoder, DeckDecoder


class ADC(unittest.TestCase):
    deck = {'heroes': [{'card_id': 4005, 'turn': 2}, {'card_id': 10014, 'turn': 1}, {'card_id': 10017, 'turn': 3},
                       {'card_id': 10026, 'turn': 1}, {'card_id': 10047, 'turn': 1}],
            'cards': [{'card_id': 3000, 'count': 2}, {'card_id': 3001, 'count': 1}, {'card_id': 10091, 'count': 3},
                      {'card_id': 10102, 'count': 3}, {'card_id': 10128, 'count': 3}, {'card_id': 10165, 'count': 3},
                      {'card_id': 10168, 'count': 3}, {'card_id': 10169, 'count': 3}, {'card_id': 10185, 'count': 3},
                      {'card_id': 10223, 'count': 1}, {'card_id': 10234, 'count': 3}, {'card_id': 10260, 'count': 1},
                      {'card_id': 10263, 'count': 1}, {'card_id': 10322, 'count': 3}, {'card_id': 10354, 'count': 3}],
            'name': 'Green/Black Example'}

    code = 'ADCJWkTZX05uwGDCRV4XQGy3QGLmqUBg4GQJgGLGgO7AaABR3JlZW4vQmxhY2sgRXhhbXBsZQ__'

    def test_encoder(self):
        encoded_deck = DeckEncoder.encode(self.deck)
        assert self.code == encoded_deck

    def test_decoder(self):
        decoded_deck = DeckDecoder.decode(self.code)
        assert decoded_deck == self.deck
