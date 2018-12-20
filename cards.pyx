# cython: language_level=3
import requests
import re
import textwrap
import pathlib
import json
import cython
from libc.stdlib cimport malloc, free
from libc.string cimport memcpy, strlen, strncpy, strcmp

cdef bint SHARE_STRUCTS = False

cache = pathlib.Path('.cache')
cache.mkdir(exist_ok=True)

def format_columns(col_width, columns):
    s = ''

    for i, (key, value) in enumerate(columns):
        position = '<' if i == 0 else '>' if i == len(columns) - 1 else '^'
        key_value_str = key + ': ' + str(value)
        s += f'{key_value_str: {position}{col_width}}'

    return s

cdef struct CardRefStruct:
    char *ref_type
    int ref_type_len
    int card_id
    int count

cdef struct CardStruct:
    char *card_name
    int card_name_len
    char *sub_type
    int sub_type_len
    char *card_text
    int card_text_len
    char *colour
    int colour_len
    char *illustrator
    int illustrator_len
    char *mini_image
    int mini_image_len
    char *large_image
    int large_image_len
    char *ingame_image
    int ingame_image_len
    char *card_type
    int card_type_len
    int card_id
    int hit_points
    int attack
    int armor
    int mana_cost
    int gold_cost
    int base_card_id
    int num_references
    CardRefStruct *references


cdef CardStruct* copy_card_struct(CardStruct* card_struct):
    cdef CardStruct *new_card_struct = <CardStruct*> malloc(cython.sizeof(CardStruct))
    if card_struct is NULL:
        return NULL
    if new_card_struct is NULL:
        raise MemoryError

    memcpy(new_card_struct, card_struct, cython.sizeof(CardStruct))

    new_card_struct.card_name = <char*> malloc(cython.sizeof(char)*(card_struct.card_name_len+1))
    if new_card_struct.card_name is NULL:
        raise MemoryError
    strncpy(new_card_struct.card_name, card_struct.card_name[:card_struct.card_name_len], card_struct.card_name_len)
    new_card_struct.card_name_len = card_struct.card_name_len

    new_card_struct.sub_type = <char*> malloc(cython.sizeof(char)*(card_struct.sub_type_len+1))
    if new_card_struct.sub_type is NULL:
        raise MemoryError
    strncpy(new_card_struct.sub_type, card_struct.sub_type[:card_struct.sub_type_len], card_struct.sub_type_len)
    new_card_struct.sub_type_len = card_struct.sub_type_len

    new_card_struct.card_text = <char*> malloc(cython.sizeof(char)*(card_struct.card_text_len+1))
    if new_card_struct.card_text is NULL:
        raise MemoryError
    strncpy(new_card_struct.card_text, card_struct.card_text[:card_struct.card_text_len], card_struct.card_text_len)
    new_card_struct.card_text_len = card_struct.card_text_len

    new_card_struct.colour = <char*> malloc(cython.sizeof(char)*(card_struct.colour_len+1))
    if new_card_struct.colour is NULL:
        raise MemoryError
    strncpy(new_card_struct.colour, card_struct.colour[:card_struct.colour_len], card_struct.colour_len)
    new_card_struct.colour_len = card_struct.colour_len

    new_card_struct.illustrator = <char*> malloc(cython.sizeof(char)*(card_struct.illustrator_len+1))
    if new_card_struct.illustrator is NULL:
        raise MemoryError
    strncpy(new_card_struct.illustrator, card_struct.illustrator[:card_struct.illustrator_len], card_struct.illustrator_len)
    new_card_struct.illustrator_len = card_struct.illustrator_len

    new_card_struct.mini_image = <char*> malloc(cython.sizeof(char)*(card_struct.mini_image_len+1))
    if new_card_struct.mini_image is NULL:
        raise MemoryError
    strncpy(new_card_struct.mini_image, card_struct.mini_image[:card_struct.mini_image_len], card_struct.mini_image_len)
    new_card_struct.mini_image_len = card_struct.mini_image_len

    new_card_struct.large_image = <char*> malloc(cython.sizeof(char)*(card_struct.large_image_len+1))
    if new_card_struct.large_image is NULL:
        raise MemoryError
    strncpy(new_card_struct.large_image, card_struct.large_image[:card_struct.large_image_len], card_struct.large_image_len)
    new_card_struct.large_image_len = card_struct.large_image_len

    new_card_struct.ingame_image = <char*> malloc(cython.sizeof(char)*(card_struct.ingame_image_len+1))
    if new_card_struct.ingame_image is NULL:
        raise MemoryError
    strncpy(new_card_struct.ingame_image, card_struct.ingame_image[:card_struct.ingame_image_len], card_struct.ingame_image_len)
    new_card_struct.ingame_image_len = card_struct.ingame_image_len

    new_card_struct.card_type = <char*> malloc(cython.sizeof(char)*(card_struct.card_type_len+1))
    if new_card_struct.card_type is NULL:
        raise MemoryError
    strncpy(new_card_struct.card_type, card_struct.card_type[:card_struct.card_type_len], card_struct.card_type_len)
    new_card_struct.card_type_len = card_struct.card_type_len

    new_card_struct.references = <CardRefStruct*>malloc(card_struct.num_references * cython.sizeof(CardRefStruct))
    if new_card_struct.references is NULL:
        raise MemoryError
    for i in range(card_struct.num_references):
        memcpy(&new_card_struct.references[i], &card_struct.references[i], cython.sizeof(CardRefStruct))
        new_card_struct.references[i].ref_type = <char*> malloc(cython.sizeof(char)*(card_struct.references[i].ref_type_len+1))
        if new_card_struct.references[i].ref_type is NULL:
            raise MemoryError
        strncpy(new_card_struct.references[i].ref_type, card_struct.references[i].ref_type, card_struct.references[i].ref_type_len)

    return new_card_struct

cdef decode(char* s, int s_len):
    return s[:s_len].decode('UTF-8')

def encode(s):
    encoded_s = s.encode('UTF-8')
    if b'\x00' in encoded_s:
        raise Exception(f'String contains null byte.\n{s}')
    return encoded_s

card_keys = ['card_name', 'card_id', 'card_type', 'references', 'mini_image', 'large_image', 'ingame_image',
             'hit_points', 'attack', 'armor', 'retaliate', 'regen', 'mana_cost', 'gold_cost', 'sub_type', 'card_text',
             'colour', 'illustrator', 'base_card_id']

cdef class Card:
    cdef CardStruct *_data
    cdef bint ptr_owner
    display_width = 60

    def __cinit__(self):
        self.ptr_owner = False

    def __dealloc__(self):
        if self._data is not NULL and self.ptr_owner is True:
            free(self._data)

            self._data = NULL

    @staticmethod
    def unpack_dict(d: dict):
        colour = ''
        for c in ['black', 'blue', 'green', 'red']:
            if ('is_' + c) in d:
                colour = c
                break

        return Card.new_card(
            card_name = encode(d['card_name']['english']),
            card_id = d['card_id'],
            card_type = encode(d['card_type']),
            references = d.get('references', []),
            mini_image = encode(d.get('mini_image', {}).get('default', '')),
            large_image = encode(d.get('large_image', {}).get('default', '')),
            ingame_image = encode(d.get('ingame_image', {}).get('default', '')),
            hit_points = d.get('hit_points', 0),
            attack = d.get('attack', 0),
            armor = d.get('armor', 0),
            retaliate = d.get('retaliate', 0),
            regen = d.get('regen', 0),
            mana_cost = d.get('mana_cost', 0),
            gold_cost = d.get('gold_cost', 0),
            sub_type = encode(d.get('sub_type', '')),
            card_text = encode(d.get('card_text', {}).get('english', '')),
            colour = encode(colour),
            illustrator = encode(d.get('illustrator', '')),
            base_card_id = d.get('base_card_id', 0)
        )

    def pack_dict(self):
        return {
            prop: self.__getattribute__(prop) for prop in card_keys
        }

    @staticmethod
    cdef Card from_ptr(CardStruct *_data, bint owner=False):
        cdef Card card = Card.__new__(Card)
        card._data = _data
        card.ptr_owner = owner
        return card

    cdef CardStruct* get_data(self):
        return self._data

    @staticmethod
    cdef Card new_card(char* card_name, int card_id, char* card_type, references, char* mini_image, char* large_image, char* ingame_image, int hit_points,
                       int attack, int armor, int retaliate, int regen, int mana_cost, int gold_cost, char* sub_type, char* card_text, char* colour, char* illustrator,
                       int base_card_id):

        cdef CardStruct *_data = <CardStruct*> malloc(cython.sizeof(CardStruct))
        if _data is NULL:
            raise MemoryError
        card_name_len = strlen(card_name)

        cdef int i = 0
        if references:
            _data.references = <CardRefStruct*> malloc(cython.sizeof(CardRefStruct)*len(references))
            if _data.references is NULL:
                raise MemoryError

            for i, reference in enumerate(references):
                encoded_ref_type = encode(reference['ref_type'])
                encoded_ref_type_length = len(encoded_ref_type)
                _data.references[i].ref_type = <char*>malloc((encoded_ref_type_length+1)*cython.sizeof(char))
                if _data.references[i].ref_type is NULL:
                    raise MemoryError
                strncpy(_data.references[i].ref_type, encoded_ref_type, encoded_ref_type_length)
                _data.references[i].ref_type_len = encoded_ref_type_length
                _data.references[i].card_id = reference['card_id']
                _data.references[i].count = reference.get('count', 0)
        else:
            _data.references = NULL


        _data.card_name = <char*> malloc(cython.sizeof(char)*(card_name_len+1))
        if _data.card_name is NULL:
            raise MemoryError
        strncpy(_data.card_name, card_name, card_name_len)
        _data.card_name_len = card_name_len

        sub_type_len = strlen(sub_type)
        _data.sub_type = <char*> malloc(cython.sizeof(char)*(sub_type_len+1))
        if _data.sub_type is NULL:
            raise MemoryError
        strncpy(_data.sub_type, sub_type, sub_type_len)
        _data.sub_type_len = sub_type_len

        card_text_len = strlen(card_text)
        _data.card_text = <char*> malloc(cython.sizeof(char)*(card_text_len+1))
        if _data.card_text is NULL:
            raise MemoryError
        strncpy(_data.card_text, card_text, card_text_len)
        _data.card_text_len = card_text_len

        colour_len = strlen(colour)
        _data.colour = <char*> malloc(cython.sizeof(char)*(colour_len+1))
        if _data.colour is NULL:
            raise MemoryError
        strncpy(_data.colour, colour, colour_len)
        _data.colour_len = colour_len

        illustrator_len = strlen(illustrator)
        _data.illustrator = <char*> malloc(cython.sizeof(char)*(illustrator_len+1))
        if _data.illustrator is NULL:
            raise MemoryError
        strncpy(_data.illustrator, illustrator, illustrator_len)
        _data.illustrator_len = illustrator_len

        mini_image_len = strlen(mini_image)
        _data.mini_image = <char*> malloc(cython.sizeof(char)*(mini_image_len+1))
        if _data.mini_image is NULL:
            raise MemoryError
        strncpy(_data.mini_image, mini_image, mini_image_len)
        _data.mini_image_len = mini_image_len

        large_image_len = strlen(large_image)
        _data.large_image = <char*> malloc(cython.sizeof(char)*(large_image_len+1))
        if _data.large_image is NULL:
            raise MemoryError
        strncpy(_data.large_image, large_image, large_image_len)
        _data.large_image_len = large_image_len

        ingame_image_len = strlen(ingame_image)
        _data.ingame_image = <char*> malloc(cython.sizeof(char)*(ingame_image_len+1))
        if _data.ingame_image is NULL:
            raise MemoryError
        strncpy(_data.ingame_image, ingame_image, ingame_image_len)
        _data.ingame_image_len = ingame_image_len

        card_type_len = strlen(card_type)
        _data.card_type = <char*> malloc(cython.sizeof(char)*(card_type_len+1))
        if _data.card_type is NULL:
            raise MemoryError
        strncpy(_data.card_type, card_type, card_type_len)
        _data.card_type_len = card_type_len

        _data.num_references = i
        _data.card_id = card_id
        _data.hit_points = hit_points
        _data.attack = attack
        _data.armor = armor
        _data.mana_cost = mana_cost
        _data.gold_cost = gold_cost
        _data.base_card_id = base_card_id

        return Card.from_ptr(_data, owner=not SHARE_STRUCTS)

    @property
    def card_name(self):
        return decode(self._data.card_name, self._data.card_name_len) \
            if self._data is not NULL and self._data.card_name is not NULL else None

    @property
    def card_id(self):
        return self._data.card_id if self._data is not NULL else None

    @property
    def card_type(self):
        return decode(self._data.card_type, self._data.card_type_len) \
            if self._data is not NULL else None

    @property
    def hit_points(self):
        return self._data.hit_points if self._data is not NULL else None

    @property
    def armor(self):
        return self._data.armor if self._data is not NULL else None

    @property
    def attack(self):
        return self._data.attack if self._data is not NULL else None

    @property
    def mana_cost(self):
        return self._data.mana_cost if self._data is not NULL else None

    @property
    def gold_cost(self):
        return self._data.gold_cost if self._data is not NULL else None

    @property
    def sub_type(self):
        return decode(self._data.sub_type, self._data.sub_type_len) \
            if self._data is not NULL and self._data.sub_type is not NULL else None

    @property
    def card_text(self):
        return decode(self._data.card_text, self._data.card_text_len) \
            if self._data is not NULL and self._data.card_text is not NULL else None

    @property
    def colour(self):
        return decode(self._data.colour, self._data.colour_len) \
            if self._data is not NULL and self._data.colour is not NULL else None

    @property
    def references(self):
        references = []
        if self._data is NULL or self._data.references is NULL:
            return None

        for i in range(self._data.num_references):
            ref_type_len = self._data.references[i].ref_type_len
            ref_type = decode(self._data.references[i].ref_type, ref_type_len)
            card_id = self._data.references[i].card_id
            d = {'ref_type': ref_type, 'card_id': card_id}
            if self._data.references[i].count:
                d['count'] = self._data.references[i].count
            references.append(d)

        return references

    @property
    def mini_image(self):
        return decode(self._data.mini_image, self._data.mini_image_len) \
            if self._data is not NULL and self._data.mini_image is not NULL else None

    @property
    def large_image(self):
        return decode(self._data.large_image, self._data.large_image_len) \
            if self._data is not NULL and self._data.large_image is not NULL else None

    @property
    def ingame_image(self):
        return decode(self._data.ingame_image, self._data.ingame_image_len) \
            if self._data is not NULL and self._data.ingame_image is not NULL else None

    @property
    def illustrator(self):
        return decode(self._data.illustrator, self._data.illustrator_len) \
            if self._data is not NULL and self._data.illustrator is not NULL else None

    @property
    def base_card_id(self):
        return self._data.base_card_id if self._data is not NULL else None

    def __str__(self):
        col_width = int(self.display_width / 2)
        lines = [f'{self.colour.upper():-^{self.display_width}}']

        lines.append(format_columns(col_width, [('Name', self.card_name), ('Type', self.card_type)]))
        if self.mana_cost or self.gold_cost:
            columns = [('Mana', self.data.mana_cost)] if self.mana_cost else [('Gold', self.gold_cost)]
            if self.sub_type:
                columns += [('Sub Type', self.sub_type)]
            lines.append(format_columns(int(self.display_width / len(columns)), columns))

        if self.card_text:
            for line in textwrap.wrap(re.sub(r'<[^<]+?>', '', self.card_text), self.display_width - 2):
                lines.append(f'{line: ^{self.display_width}}')

        if self.attack is not None and self.hit_points:
            columns = [('Attack', self.attack)]
            if self.armor: columns += [('Armor', self.armor)]
            columns += [('HP', self.hit_points)]

            lines.append(format_columns(int(self.display_width / len(columns)), columns))

        lines.append(f'{self.colour.upper():-^{self.display_width}}')
        return '\n'.join(lines)


cdef class CardList:
    cdef CardStruct **_cards
    cdef bint ptr_owner
    cdef int _length

    def __cinit__(self):
        self._length = 0
        self.ptr_owner = False

    def __dealloc__(self):
        if self._cards is not NULL and self.ptr_owner is True:
            for i in range(self._length):
                free(self._cards[i])
            free(self._cards)
            self._cards = NULL

    @staticmethod
    def new_card_list(cards):
        cdef CardStruct** cards_ptr = <CardStruct**> malloc(len(cards)*8)
        if cards_ptr is NULL:
            raise MemoryError
        cdef Card card

        for i, card in enumerate(cards):
            if SHARE_STRUCTS:
                cards_ptr[i] = card.get_data()
            else:
                cards_ptr[i] = copy_card_struct(card.get_data())

        return CardList.from_ptr(cards_ptr, i, not SHARE_STRUCTS)

    def __add__(x, y):
        if not isinstance(x, CardList) or not isinstance(y, CardList):
            return NotImplemented

        cdef CardList xc = <CardList> x
        cdef CardList yc = <CardList> y

        _cards = <CardStruct**>malloc(8 * (len(xc) + len(yc)))
        if _cards is NULL:
            raise MemoryError

        for i in range(len(xc)):
            _cards[i] = copy_card_struct(<CardStruct*>xc._cards[i])

        for j in range(len(yc)):
            _cards[i+j] = copy_card_struct(<CardStruct*>yc._cards[j])

        return CardList.from_ptr(_cards, i+j, True)

    @staticmethod
    cdef CardList from_ptr(CardStruct** cards_ptr, int length, bint owner=False):
        cdef CardList card_list = CardList.__new__(CardList)

        card_list._cards = cards_ptr
        card_list._length = length
        card_list.ptr_owner = owner

        return card_list

    cpdef int get_idx_by_id(self, int card_id):
        cdef int i = 0
        for i in range(self._length):
            if self._cards[i].card_id == card_id:
                return i
        return -1

    cpdef int get_idx_by_name(self, char* card_name):
        cdef int i = 0
        for i in range(self._length):
            if strcmp(self._cards[i].card_name, card_name) == 0:
                return i
        return -1

    def get_card_by_id(self, card_id):
        cdef Card card = Card.from_ptr(self._cards[self.get_idx_by_id(card_id)])
        return card

    def get_card_by_name(self, card_name):
        encoded_card_name = encode(card_name)
        cdef char *cn = encoded_card_name
        cdef Card card = Card.from_ptr(self._cards[self.get_idx_by_name(cn)])
        return card

    def __getitem__(self, item):
        if item > self._length:
            raise IndexError
        card = Card()
        cdef int i = item
        card._data = self._cards[i]
        card.ptr_owner = False

        return card

    def __len__(self):
        return self._length

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
        card_list = CardList.new_card_list([Card.unpack_dict(d) for d in card_set_dict['card_list']])
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

    def get_card_by_name(self, name):
        return self.cards.get_card_by_name(name)

    def __len__(self):
        return len(self.cards)

class Deck:
    def __init__(self, heroes, main_deck, items, name=''):
        self.heroes = heroes
        self.main_deck = main_deck
        self.items = items
        self.name = name

    def is_valid(self):
        if not (len(self.heroes) == 5 and len(self.main_deck) >= 40 and len(self.items) >= 9):
            return False

        for hero in self.heroes:
            for reference in hero.references:
                found = 0
                count = reference['count']
                for card in self.main_deck:
                    if card.card_id == reference['card_id']:
                        found += 1
                if found != count:
                    return False

        return True

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