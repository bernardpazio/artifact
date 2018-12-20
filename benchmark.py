import time
import datetime

import adc_py
import cards_py

import pyximport; pyximport.install()

import adc_c
import cards_c

from artifact import adc
from artifact import cards

import random


def run(name, cardlib, adclib):
    start = time.time()

    all_cards = cardlib.CardSet.load_card_set('00').cards + cardlib.CardSet.load_card_set('01').cards

    hero_cards = [card for card in all_cards if card.card_type == 'Hero']
    sig_cards = []
    for hero_card in hero_cards:
        for ref in hero_card.references:
            if ref['ref_type'] == 'includes':
                ref_card = None
                for card in all_cards:
                    if card.card_id == ref['card_id']:
                        ref_card = card
                sig_cards.append(ref_card)

    item_cards = [card for card in all_cards if card.card_type == 'Item']

    playable_cards = []
    for card in all_cards:
        if card not in sig_cards and card.card_type in ['Spell', 'Creep', 'Improvement']:
            playable_cards.append(card)

    load_time = time.time() - start

    def deck_generator(count=100):
        for i in range(count):
            heroes = [random.choice(hero_cards) for i in range(5)]

            items = [random.choice(item_cards) for i in range(random.randint(9, 18))]

            main_deck = [random.choice(playable_cards) for i in range(random.randint(25, 50))]

            yield cardlib.Deck(heroes, main_deck, items, str(i))

    start = time.time()
    runs = 1000
    gen_start = time.time()
    total_gen_time = 0
    for deck in deck_generator(runs):
        gen_end = time.time()
        total_gen_time += gen_end - gen_start

        deck_code_dict = deck.to_code_deck_dict()
        deck_code_encode = adclib.DeckEncoder.encode(deck_code_dict)
        deck_code_decode = adclib.DeckDecoder.decode(deck_code_encode)
        new_deck = cardlib.Deck.from_code_deck_dict(deck_code_decode, all_cards)

        gen_start = time.time()

    end = time.time()
    total_time = end - start
    encode_decode_time = total_time - total_gen_time
    print(f'{name} for {runs} runs:', datetime.timedelta(seconds=total_time))
    print(f'gen_time: {total_gen_time: .3f}s | ed_time: {encode_decode_time: .3f}s | load_time: {load_time: .3f}s')


run('Pure Python', cards_py, adc_py)
run('Cython', cards_c, adc_c)
run('"Optimized" Cython', cards, adc)
