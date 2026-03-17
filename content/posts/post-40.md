---
title: "Simulating Texas Hold'em With Groovy"
slug: ""
author: "Todd Sharp"
date: 2018-08-07
summary: "A simple \"texas hold'em\" simulation written as a coding exercise with Groovy."
tags: ["Groovy"]
keywords: "groovy, cards, playing cards, texas holdem, coding exercise, fun"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/40/banner_54e1d54a4b51b108f5d084609629307c143edbe0554c704c7c2b79d79349c25f_1280.jpg"
---

Last week I had a bit of free time and decided to see how difficult it would be to write a Texas Hold'em poker simulation in Groovy.  My goal wasn't to come up with a full blown game, but something simple.  Create a "deck" of cards, shuffle the cards, deal the cards to the players and deal out a set of community cards.  If you're not familiar with Texas Hold'em the game is pretty straightforward:  2 to 10 players each receive two down ("hole") cards and then five community cards are dealt face up in three stages:  three at first (called the "flop"), then two rounds of one card (called the "turn" and the "river" respectively).  A card is "burned" or discarded prior to each round of community cards.  The players make their best five card poker hand using the seven cards - their two hole cards and the five community cards.  They can use any combination - use of the hole cards is not necessary to make their "best" hand. That's pretty much all there is to it - I won't get into betting or strategy here as that's beyond the scope of the discussion for these purposes.

![](https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/aces.jpg)\
Credit [[fulltiltpoker.com]](http://www.fulltiltpoker.com/)

So now that we've explained the game, let's take a look at what I came up with.  I'm not claiming this is the most efficient or "right" way to build a hold'em simulation, just how I completed the exercise.

The first step in my mind was to build the deck.  Obviously I could have simply created an array containing all of the 52 possible cards in a deck of playing cards, but being a programmer our first inclination is often to find patterns and use techniques to solve a problem instead of using "brute force".  The obvious pattern in a deck of playing cards is that there are 4 different suits - hearts, spades, clubs and diamonds and 13 repeating cards (from Ace to King) in each deck.  So that was my starting point - create an array of suits and an array of cards and an empty array for the resulting deck:
```groovy
def suits = ['❤️', '♠️', '♣️', '♦️']
def cards = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K']
def deck = []
```



Yes, I did think that emoji were a perfectly valid solution in this case.  It's not every day that you get to use emoji in your codebase, so I went "all in" on that approach. The next step was to build the deck.  Groovy gives us a really [nice way to do this with its built in Collection methods](http://docs.groovy-lang.org/latest/html/api/groovy/util/GroovyCollections.html#combinations-java.lang.Iterable-) so that part just takes creating a `List` that contains the cards and the suits and calling `combinations()` on it.  Then I loop over it and "join" the results to get the representation of a card
```groovy
[cards, suits].combinations().each {
    deck << it.join()
}
```



Now we have to "shuffle" the deck to randomize the cards within it.  Java gives us the `Collections.shuffle()` method, so let's use that:
```groovy
Collections.shuffle(deck)
```



Next up we need to deal the "hole cards" for each player.  I decided upon an array of arrays for the player hands - the amount of arrays within the outer hands array represent each player.  Since each player gets two cards, I do an outer loop for each card, and an inner loop for each player - each inner loop removing the first card from the array and placing it into the appropriate player's "hand":
```groovy
println "Shuffled deck--> ${deck}"

def hands = [ [], [], [], [], [], [], [], [] ]
def cardsPerPlayer = 2

(0..cardsPerPlayer-1).each {
    hands.each {
        it << deck.remove(0)
    }
}

println "Player hands--> ${hands}"
```



Now we turn our attention towards the community cards.  As stated earlier, before each round of community cards is dealt we must "burn" or discard a single card.  Side note: this is done to deter cheating - if a card is "marked" somehow on the outside a certain player or players can have an unfair advantage in betting by looking at the top card of the deck.  By discarding first, no one can visibly see the outside of the next card so the theory is that they are deterred from cheating.  I decided to create a reusable Closure for the deal action - since it will be done multiple times.  The closure accepts an integer representing the amount of cards to be dealt after burning a single card. 
```groovy
// community cards
def communityCards = []
def burnPile = []

def deal = { int c = 0 ->
    burnPile << deck.remove(0)
    (0..( c - 1 )).each {
        communityCards << deck.remove(0)
    }
}

deal(3)

println "Flop --> ${communityCards}"
deal(1)
println "Turn --> ${communityCards}"
deal(1)
println "River --> ${communityCards}"
```



And here is how the simulation might look once the script has been run:
```groovy
Shuffled deck--> [8♣️, 9♦️, 6♣️, 8♠️, 3♠️, 7♠️, 5♦️, K♠️, 2♠️, 3♦️, 6♠️, K♣️, 5♣️, 4❤️, 7❤️, 3❤️, 4♣️, 9❤️, Q♦️, A♦️, 6❤️, Q❤️, 2♣️, 7♣️, 4♦️, K❤️, 2♦️, 5❤️, 5♠️, A♣️, 7♦️, 2❤️, 9♠️, J♠️, 3♣️, 6♦️, 10♣️, 10♦️, K♦️, J♦️, 9♣️, A♠️, J❤️, 10❤️, J♣️, 10♠️, 4♠️, Q♠️, Q♣️, A❤️, 8❤️, 8♦️]
Player hands--> [[8♣️, 2♠️], [9♦️, 3♦️], [6♣️, 6♠️], [8♠️, K♣️], [3♠️, 5♣️], [7♠️, 4❤️], [5♦️, 7❤️], [K♠️, 3❤️]]
Flop --> [9❤️, Q♦️, A♦️]
Turn --> [9❤️, Q♦️, A♦️, Q❤️]
River --> [9❤️, Q♦️, A♦️, Q❤️, 7♣️]
```



In my next post I might take a look at recreating the exercise using JavaScript.  Let me know in the comments how you might have solved it differently!

Image by [12019](https://pixabay.com/users/12019-12019) from [Pixabay](https://pixabay.com)
