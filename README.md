# Artifact Card API with DeckCode Encoder/Decoder

This is a simple project creating a wrapper around Artifacts card API. It calls the Artifact web API then unpacks 
the resulting json into a python object representation with helpful classes such as CardList for easy lookup of 
cards from their ID or name. This is writen in Cython for extremely fast lookups, this is probably not needed for 
most use cases, but I wanted to experiment with Cython.

## Getting Started

Using this project should be fairly simple, it does require Cython for development however.

### Prerequisites

Simply install requirement.txt with pip this is only required for development, setuptools should handle the install
requirements.

```
pip install -r requirements.txt
```

### Installing

This does not require cython for installing as the c source code should be distributed with project

```
python setup.py install
```

or

```
python setep.py build_ext --inplace
```

if you are using cython and do not wish to install the project to your python packages

## Using the library

This library has two extensions artifact.adc and artifact.cards. the adc extension contains the encoder / decoder for
Artifacts deck code and cards contains all the functionality for retrieving card sets from Artifacts card API and the
handling of card objects.

### adc

The adc extension is very simple it has DeckEncoder and DeckDecoder.

To decode a deck code

```python
from artifact import adc

adc.DeckDecoder.decode(deck_code)
```

Encoding to a deck code requires a dictionary of the form

```python
{
    'heroes': [
        {'card_id': card_id, 'turn': turn},
        ...
    ],
    'cards': [
        {'card_id':  card_id, 'count': count},
        ...
    ],
    'name': name
}
```

Where the number of heroes is 5 and where 3 are turn 1, 1 is turn 2 and 1 is turn 3. You can get a correctly formatted
dict from the cards.Deck.to_code_deck_dict

### cards

You can load a card set from Artifact with

```python
from artifact import cards

card_set = cards.CardSet.load_card_set(set_code)
```

Sets are numbered 00 01 etc, as of writing there are only 2 sets but there will be more in the future. I am
assuming they will follow the same pattern. You can then construct a deck by finding cards in the set using 
either get_card_by_name or get_card_by_id

```python
heroes = [
    card_set.get_by_name('Debbi the Cunning'),
    ...
]
main_deck = [
    card_set.get_by_name('No Accident'),
    ...
]
items = [
    card_set.get_by_name("Traveler's Cloak"),
    ...
]
deck = cards.Deck(heroes, main_deck, items, name='My Deck')
```

now you can get a dict suitable for the encoder

```python
deck_code_dict = deck.to_code_deck_dict()
deck_code = adc.DeckEncoder(deck_code_dict)
```

you then use this deck code on playartifact.com to view it

```python
url = f'https://playartifact.com/d/{deck_code}'
```

## Authors

* **Bernard Pazio** - *Initial work* - [BernardPazio](https://github.com/BernardPazio)

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Footnotes

If you are interested in the speed ups I was able to achieve using cython over pure python here is a run down
from my benchmark file.

```
Pure Python for 1000 runs: 0:00:00.873351
gen_time:  0.060s | ed_time:  0.814s | load_time:  0.038s
Cython for 1000 runs: 0:00:00.532902
gen_time:  0.059s | ed_time:  0.474s | load_time:  0.034s
"Optimized" Cython for 1000 runs: 0:00:00.214757
gen_time:  0.056s | ed_time:  0.159s | load_time:  0.037s
```

So when simply compiling the code with cython we see around a 40% improvement, pretty good. However when we
optimize by implementing extension classes to contain c structs as the data structure we see a massive 66% increase
over base cython and a 80% increase over pure python.