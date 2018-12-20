import requests
import re
import textwrap
import pathlib
import json

cache = pathlib.Path('.cache')
cache.mkdir(exist_ok=True)


def format_columns(col_width, columns):
    s = ''

    for i, (key, value) in enumerate(columns):
        position = '<' if i == 0 else '>' if i == len(columns) - 1 else '^'
        key_value_str = key + ': ' + str(value)
        s += f'{key_value_str: {position}{col_width}}'

    return s


class Card:
    def __init__(self, card_name, card_id, card_type, hit_points=None, attack=None, armor=None, retaliate=None,
                 regen=None, mana_cost=None, gold_cost=None, sub_type=None, card_text=None, colour=None,
                 references=None,
                 display_width=60, ability=None, mini_image=None, large_image=None, ingame_image=None, illustrator=None,
                 base_card_id=None):
        self.display_width = 60
        self.name = card_name
        self.card_id = card_id
        self.card_type = card_type
        self.hit_points = hit_points
        self.attack = attack
        self.armor = armor
        self.retaliate = retaliate
        self.regen = regen
        self.mana_cost = mana_cost
        self.gold_cost = gold_cost
        self.sub_type = sub_type
        self.card_text = card_text
        self.colour = colour
        self.references = references
        self.display_width = display_width
        self.ability = ability
        self.mini_image = mini_image
        self.large_image = large_image
        self.ingame_image = ingame_image
        self.illustrator = illustrator
        self.base_card_id = base_card_id

    @staticmethod
    def unpack_dict(d):
        colour = ''
        for c in ['black', 'blue', 'green', 'red']:
            if ('is_' + c) in d:
                colour = c
                break

        return Card(**{
            'card_name': d['card_name']['english'],
            'card_id': d['card_id'],
            'card_type': d['card_type'],
            'hit_points': d.get('hit_points'),
            'attack': d.get('attack'),
            'armor': d.get('armor'),
            'retaliate': d.get('retaliate'),
            'regen': d.get('regen'),
            'mana_cost': d.get('mana_cost'),
            'gold_cost': d.get('gold_cost'),
            'sub_type': d.get('sub_type'),
            'card_text': None if 'card_text' not in d else d['card_text'].get('english'),
            'colour': colour,
            'references': d.get('references'),
            'mini_image': d.get('mini_image'),
            'large_image': d.get('large_image'),
            'ingame_image': d.get('ingame_image'),
            'illustrator': d.get('illustrator'),
            'base_card_id': d.get('base_card_id')
        })

    def __str__(self):
        col_width = int(self.display_width / 2)
        lines = [f'{self.colour.upper():-^{self.display_width}}']

        lines.append(format_columns(col_width, [('Name', self.card_name), ('Type', self.card_type)]))
        if self.mana_cost or self.gold_cost:
            columns = [('Mana', self.mana_cost)] if self.mana_cost else [('Gold', self.gold_cost)]
            if self.sub_type:
                columns += [('Sub Type', self.sub_type)]
            lines.append(format_columns(int(self.display_width / len(columns)), columns))

        if self.text:
            for line in textwrap.wrap(re.sub(r'<[^<]+?>', '', self.text), self.display_width - 2):
                lines.append(f'{line: ^{self.display_width}}')

        if self.attack is not None and self.hit_points:
            columns = [('Attack', self.attack)]
            if self.armor: columns += [('Armor', self.armor)]
            columns += [('HP', self.hit_points)]

            lines.append(format_columns(int(self.display_width / len(columns)), columns))

        lines.append(f'{self.colour.upper():-^{self.display_width}}')
        return '\n'.join(lines)


class CardList:
    def __init__(self, cards):
        self.cards = cards

    def get_card_by_id(self, card_id):
        for card in self.cards:
            if card.card_id == card_id:
                return card

    def __getitem__(self, item):
        return self.cards.__getitem__(item)

    def __len__(self):
        return len(self.cards)

    def __add__(self, other):
        cards = self.cards + other.cards
        return CardList(cards)


class CardSet:
    def __init__(self, set_name, set_code, set_id, version, cards):
        self.set_name = set_name
        self.set_code = set_code
        self.set_id = set_id
        self.version = version
        self.cards = cards

    @staticmethod
    def get_card_set(set_code):
        set_cache_path = cache / f'{set_code}.json'
        if not set_cache_path.exists():
            request_url = f'https://playartifact.com/cardset/{set_code}/'
            r = requests.get(request_url)

            if r.status_code != 200:
                raise Exception(f'{r.status_code}: {request_url}')

            data = r.json()
            set_url = data['cdn_root'] + data['url']

            r = requests.get(set_url)

            if r.status_code != 200:
                raise Exception(f'{r.status_code}: {set_url}')

            card_set_json = r.json()
            with open(set_cache_path, 'w') as set_cache:
                set_cache.write(r.content.decode('utf-8'))

        else:
            with open(set_cache_path, 'r') as set_cache:
                card_set_json = json.loads(set_cache.read())

        return card_set_json

    @staticmethod
    def load_card_set(set_code):
        data = CardSet.get_card_set(set_code)

        card_set_dict = data['card_set']
        card_list = CardList([Card.unpack_dict(d) for d in card_set_dict['card_list']])
        set_info = card_set_dict['set_info']

        card_set = CardSet(
            set_info['name']['english'],
            set_code,
            set_info['set_id'],
            card_set_dict['version'],
            card_list
        )

        return card_set

    def get_card_by_id(self, card_id):
        return self.cards.get_card_by_id(card_id)

    def __len__(self):
        return len(self.cards)


class Deck:
    def __init__(self, heroes, main_deck, items, name=''):
        self.heroes = heroes
        self.main_deck = main_deck
        self.items = items
        self.name = name

    def is_valid(self):
        return len(self.heroes) == 5 and len(self.main_deck) >= 40 and len(self.items) >= 9

    def to_code_deck_dict(self):
        deck = {'heroes': [], 'cards': [], 'name': self.name}
        hero_cards = []
        for i, hero in enumerate(self.heroes):
            deck['heroes'].append({'card_id': hero.card_id, 'turn': i - 1 if i > 2 else 1})
            for ref in hero.references:
                if ref['ref_type'] == 'includes':
                    hero_cards.append(ref['card_id'])
        cards = {}

        for card in self.main_deck + self.items:
            if card.card_id in hero_cards:
                continue
            if card.card_id in cards:
                cards[card.card_id]['count'] += 1
            else:
                cards[card.card_id] = {'card_id': card.card_id, 'count': 1}

        deck['cards'] = cards.values()

        return deck

    @staticmethod
    def from_code_deck_dict(d, card_pool: CardList):
        heroes = []
        main_deck = []
        items = []
        for hero_dict in d['heroes']:
            hero = card_pool.get_card_by_id(hero_dict['card_id'])
            heroes.append(hero)
            sig_card_id = 0
            include_count = 0
            for ref in hero.references:
                if ref['ref_type'] == 'includes':
                    sig_card_id = ref['card_id']
                    include_count = ref['count']
                    break

            sig_card = card_pool.get_card_by_id(sig_card_id)
            main_deck += [sig_card] * include_count

        for card_dict in d['cards']:
            card = card_pool.get_card_by_id(card_dict['card_id'])
            if card is None:
                raise Exception()
            if card.card_type == 'Item':
                items += [card] * card_dict['count']
            else:
                main_deck += [card] * card_dict['count']

        return Deck(heroes, main_deck, items, d.get('name', ''))
