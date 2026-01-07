// Kuratierte Liste beliebter Filme, Serien und Kinderinhalte
// Diese werden für den Hero-Banner und "Beliebt"-Sections verwendet

/// Kategorien für kuratierte Inhalte
enum CuratedCategory {
  movie,
  series,
  kids,
  documentary,
}

class CuratedTitle {
  final String name;
  final CuratedCategory category;
  final bool spotlight; // Kann als Hero-Banner angezeigt werden
  final List<String> alternativeNames; // Alternative Schreibweisen
  final int? year; // Erscheinungsjahr für besseres Matching

  const CuratedTitle(
    this.name,
    this.category, {
    this.spotlight = false,
    this.alternativeNames = const [],
    this.year,
  });
}

/// Kuratierte Inhalte - bekannte und beliebte Titel
class CuratedContent {
  CuratedContent._();

  // ============================================
  // SERIEN - Beliebte & Klassiker
  // ============================================
  static const List<CuratedTitle> series = [
    // Top-Tier (Spotlight-würdig)
    CuratedTitle('Breaking Bad', CuratedCategory.series, spotlight: true, year: 2008),
    CuratedTitle('Game of Thrones', CuratedCategory.series, spotlight: true, year: 2011),
    CuratedTitle('Stranger Things', CuratedCategory.series, spotlight: true, year: 2016),
    CuratedTitle('The Last of Us', CuratedCategory.series, spotlight: true, year: 2023),
    CuratedTitle('House of the Dragon', CuratedCategory.series, spotlight: true, year: 2022),
    CuratedTitle('The Witcher', CuratedCategory.series, spotlight: true, year: 2019),
    CuratedTitle('The Mandalorian', CuratedCategory.series, spotlight: true, year: 2019),
    CuratedTitle('Squid Game', CuratedCategory.series, spotlight: true, year: 2021),
    CuratedTitle('Wednesday', CuratedCategory.series, spotlight: true, year: 2022),
    CuratedTitle('The Bear', CuratedCategory.series, spotlight: true, year: 2022),
    CuratedTitle('Shogun', CuratedCategory.series, spotlight: true, year: 2024),
    CuratedTitle('Fallout', CuratedCategory.series, spotlight: true, year: 2024),
    CuratedTitle('3 Body Problem', CuratedCategory.series, spotlight: true, alternativeNames: ['Three Body Problem', '3-Body Problem'], year: 2024),
    CuratedTitle('Reacher', CuratedCategory.series, spotlight: true, year: 2022),
    CuratedTitle('The Boys', CuratedCategory.series, spotlight: true, year: 2019),
    CuratedTitle('Severance', CuratedCategory.series, spotlight: true, year: 2022),
    CuratedTitle('Slow Horses', CuratedCategory.series, spotlight: true, year: 2022),
    CuratedTitle('Dark', CuratedCategory.series, spotlight: true, year: 2017),
    CuratedTitle('1899', CuratedCategory.series, spotlight: true, year: 2022),
    CuratedTitle('Arcane', CuratedCategory.series, spotlight: true, year: 2021),

    // Weitere beliebte Serien
    CuratedTitle('Better Call Saul', CuratedCategory.series, year: 2015),
    CuratedTitle('The Crown', CuratedCategory.series, year: 2016),
    CuratedTitle('Peaky Blinders', CuratedCategory.series, year: 2013),
    CuratedTitle('Money Heist', CuratedCategory.series, alternativeNames: ['La Casa de Papel', 'Haus des Geldes'], year: 2017),
    CuratedTitle('Narcos', CuratedCategory.series, year: 2015),
    CuratedTitle('Ozark', CuratedCategory.series, year: 2017),
    CuratedTitle('The Queen\'s Gambit', CuratedCategory.series, alternativeNames: ['Das Damengambit'], year: 2020),
    CuratedTitle('Chernobyl', CuratedCategory.series, year: 2019),
    CuratedTitle('True Detective', CuratedCategory.series, year: 2014),
    CuratedTitle('Fargo', CuratedCategory.series, year: 2014),
    CuratedTitle('The Expanse', CuratedCategory.series, year: 2015),
    CuratedTitle('Black Mirror', CuratedCategory.series, year: 2011),
    CuratedTitle('Westworld', CuratedCategory.series, year: 2016),
    CuratedTitle('The Walking Dead', CuratedCategory.series, year: 2010),
    CuratedTitle('Vikings', CuratedCategory.series, year: 2013),
    CuratedTitle('The Handmaid\'s Tale', CuratedCategory.series, year: 2017),
    CuratedTitle('Succession', CuratedCategory.series, year: 2018),
    CuratedTitle('Ted Lasso', CuratedCategory.series, year: 2020),
    CuratedTitle('The Morning Show', CuratedCategory.series, year: 2019),
    CuratedTitle('Foundation', CuratedCategory.series, year: 2021),
    CuratedTitle('For All Mankind', CuratedCategory.series, year: 2019),
    CuratedTitle('Silo', CuratedCategory.series, year: 2023),
    CuratedTitle('The Diplomat', CuratedCategory.series, year: 2023),
    CuratedTitle('Beef', CuratedCategory.series, year: 2023),
    CuratedTitle('Yellowjackets', CuratedCategory.series, year: 2021),
    CuratedTitle('The White Lotus', CuratedCategory.series, year: 2021),
    CuratedTitle('Euphoria', CuratedCategory.series, year: 2019),
    CuratedTitle('Barry', CuratedCategory.series, year: 2018),
    CuratedTitle('What We Do in the Shadows', CuratedCategory.series, year: 2019),
    CuratedTitle('Only Murders in the Building', CuratedCategory.series, year: 2021),
    CuratedTitle('Abbott Elementary', CuratedCategory.series, year: 2021),
    CuratedTitle('Andor', CuratedCategory.series, year: 2022),
    CuratedTitle('Obi-Wan Kenobi', CuratedCategory.series, year: 2022),
    CuratedTitle('The Book of Boba Fett', CuratedCategory.series, year: 2021),
    CuratedTitle('Loki', CuratedCategory.series, year: 2021),
    CuratedTitle('WandaVision', CuratedCategory.series, year: 2021),
    CuratedTitle('Ahsoka', CuratedCategory.series, year: 2023),
    CuratedTitle('The Acolyte', CuratedCategory.series, year: 2024),
    CuratedTitle('Echo', CuratedCategory.series, year: 2024),
    CuratedTitle('Invincible', CuratedCategory.series, year: 2021),
    CuratedTitle('The Gentlemen', CuratedCategory.series, year: 2024),
    CuratedTitle('Ripley', CuratedCategory.series, year: 2024),
    CuratedTitle('Baby Reindeer', CuratedCategory.series, year: 2024),
    CuratedTitle('Presumed Innocent', CuratedCategory.series, year: 2024),
    CuratedTitle('The Penguin', CuratedCategory.series, year: 2024),
    CuratedTitle('Agatha All Along', CuratedCategory.series, year: 2024),

    // Deutsche Serien
    CuratedTitle('Babylon Berlin', CuratedCategory.series, spotlight: true, year: 2017),
    CuratedTitle('How to Sell Drugs Online (Fast)', CuratedCategory.series, year: 2019),
    CuratedTitle('Biohackers', CuratedCategory.series, year: 2020),
    CuratedTitle('Kleo', CuratedCategory.series, year: 2022),
    CuratedTitle('Die Kaiserin', CuratedCategory.series, alternativeNames: ['The Empress'], year: 2022),
    CuratedTitle('Tatort', CuratedCategory.series, year: 1970),
    CuratedTitle('Der Tatortreiniger', CuratedCategory.series, year: 2011),

    // Klassiker
    CuratedTitle('The Sopranos', CuratedCategory.series, year: 1999),
    CuratedTitle('The Wire', CuratedCategory.series, year: 2002),
    CuratedTitle('Lost', CuratedCategory.series, year: 2004),
    CuratedTitle('Prison Break', CuratedCategory.series, year: 2005),
    CuratedTitle('Dexter', CuratedCategory.series, year: 2006),
    CuratedTitle('Mad Men', CuratedCategory.series, year: 2007),
    CuratedTitle('Sons of Anarchy', CuratedCategory.series, year: 2008),
    CuratedTitle('Downton Abbey', CuratedCategory.series, year: 2010),
    CuratedTitle('Sherlock', CuratedCategory.series, year: 2010),
    CuratedTitle('Homeland', CuratedCategory.series, year: 2011),
    CuratedTitle('House of Cards', CuratedCategory.series, year: 2013),
    CuratedTitle('Mr. Robot', CuratedCategory.series, year: 2015),
    CuratedTitle('Mindhunter', CuratedCategory.series, year: 2017),

    // Sitcoms & Comedy
    CuratedTitle('The Office', CuratedCategory.series, year: 2005),
    CuratedTitle('Friends', CuratedCategory.series, year: 1994),
    CuratedTitle('How I Met Your Mother', CuratedCategory.series, year: 2005),
    CuratedTitle('The Big Bang Theory', CuratedCategory.series, year: 2007),
    CuratedTitle('Brooklyn Nine-Nine', CuratedCategory.series, year: 2013),
    CuratedTitle('Parks and Recreation', CuratedCategory.series, year: 2009),
    CuratedTitle('Schitt\'s Creek', CuratedCategory.series, year: 2015),
    CuratedTitle('Fleabag', CuratedCategory.series, year: 2016),
    CuratedTitle('The Good Place', CuratedCategory.series, year: 2016),
    CuratedTitle('Young Sheldon', CuratedCategory.series, year: 2017),
  ];

  // ============================================
  // FILME - Beliebte & Klassiker
  // ============================================
  static const List<CuratedTitle> movies = [
    // Top-Tier (Spotlight-würdig)
    CuratedTitle('Oppenheimer', CuratedCategory.movie, spotlight: true, year: 2023),
    CuratedTitle('Dune', CuratedCategory.movie, spotlight: true, year: 2021),
    CuratedTitle('Dune: Part Two', CuratedCategory.movie, spotlight: true, alternativeNames: ['Dune 2', 'Dune Part 2'], year: 2024),
    CuratedTitle('Barbie', CuratedCategory.movie, spotlight: true, year: 2023),
    CuratedTitle('Avatar: The Way of Water', CuratedCategory.movie, spotlight: true, alternativeNames: ['Avatar 2'], year: 2022),
    CuratedTitle('Top Gun: Maverick', CuratedCategory.movie, spotlight: true, year: 2022),
    CuratedTitle('The Batman', CuratedCategory.movie, spotlight: true, year: 2022),
    CuratedTitle('Spider-Man: No Way Home', CuratedCategory.movie, spotlight: true, year: 2021),
    CuratedTitle('No Time to Die', CuratedCategory.movie, spotlight: true, year: 2021),
    CuratedTitle('Tenet', CuratedCategory.movie, spotlight: true, year: 2020),
    CuratedTitle('Joker', CuratedCategory.movie, spotlight: true, year: 2019),
    CuratedTitle('Joker: Folie à Deux', CuratedCategory.movie, spotlight: true, alternativeNames: ['Joker 2'], year: 2024),
    CuratedTitle('Poor Things', CuratedCategory.movie, spotlight: true, year: 2023),
    CuratedTitle('Killers of the Flower Moon', CuratedCategory.movie, spotlight: true, year: 2023),
    CuratedTitle('Napoleon', CuratedCategory.movie, spotlight: true, year: 2023),
    CuratedTitle('Gladiator II', CuratedCategory.movie, spotlight: true, alternativeNames: ['Gladiator 2'], year: 2024),
    CuratedTitle('Deadpool & Wolverine', CuratedCategory.movie, spotlight: true, alternativeNames: ['Deadpool 3'], year: 2024),
    CuratedTitle('Furiosa', CuratedCategory.movie, spotlight: true, year: 2024),
    CuratedTitle('Kingdom of the Planet of the Apes', CuratedCategory.movie, spotlight: true, year: 2024),
    CuratedTitle('Godzilla x Kong: The New Empire', CuratedCategory.movie, spotlight: true, year: 2024),

    // Action & Sci-Fi
    CuratedTitle('Inception', CuratedCategory.movie, spotlight: true, year: 2010),
    CuratedTitle('Interstellar', CuratedCategory.movie, spotlight: true, year: 2014),
    CuratedTitle('The Dark Knight', CuratedCategory.movie, spotlight: true, year: 2008),
    CuratedTitle('Mad Max: Fury Road', CuratedCategory.movie, spotlight: true, year: 2015),
    CuratedTitle('John Wick', CuratedCategory.movie, year: 2014),
    CuratedTitle('John Wick: Chapter 4', CuratedCategory.movie, spotlight: true, alternativeNames: ['John Wick 4'], year: 2023),
    CuratedTitle('The Matrix', CuratedCategory.movie, year: 1999),
    CuratedTitle('Blade Runner 2049', CuratedCategory.movie, year: 2017),
    CuratedTitle('Arrival', CuratedCategory.movie, year: 2016),
    CuratedTitle('Edge of Tomorrow', CuratedCategory.movie, year: 2014),
    CuratedTitle('Ex Machina', CuratedCategory.movie, year: 2014),
    CuratedTitle('District 9', CuratedCategory.movie, year: 2009),
    CuratedTitle('Gravity', CuratedCategory.movie, year: 2013),
    CuratedTitle('The Martian', CuratedCategory.movie, alternativeNames: ['Der Marsianer'], year: 2015),
    CuratedTitle('Mission: Impossible', CuratedCategory.movie, year: 1996),
    CuratedTitle('Mission: Impossible - Dead Reckoning', CuratedCategory.movie, year: 2023),
    CuratedTitle('Fast X', CuratedCategory.movie, alternativeNames: ['Fast & Furious 10'], year: 2023),
    CuratedTitle('Aquaman and the Lost Kingdom', CuratedCategory.movie, year: 2023),
    CuratedTitle('The Flash', CuratedCategory.movie, year: 2023),
    CuratedTitle('Blue Beetle', CuratedCategory.movie, year: 2023),

    // Drama
    CuratedTitle('Parasite', CuratedCategory.movie, spotlight: true, year: 2019),
    CuratedTitle('1917', CuratedCategory.movie, spotlight: true, year: 2019),
    CuratedTitle('The Shawshank Redemption', CuratedCategory.movie, alternativeNames: ['Die Verurteilten'], year: 1994),
    CuratedTitle('Forrest Gump', CuratedCategory.movie, year: 1994),
    CuratedTitle('The Godfather', CuratedCategory.movie, alternativeNames: ['Der Pate'], year: 1972),
    CuratedTitle('Fight Club', CuratedCategory.movie, year: 1999),
    CuratedTitle('Pulp Fiction', CuratedCategory.movie, year: 1994),
    CuratedTitle('Schindler\'s List', CuratedCategory.movie, alternativeNames: ['Schindlers Liste'], year: 1993),
    CuratedTitle('The Green Mile', CuratedCategory.movie, year: 1999),
    CuratedTitle('Whiplash', CuratedCategory.movie, year: 2014),
    CuratedTitle('The Revenant', CuratedCategory.movie, year: 2015),
    CuratedTitle('La La Land', CuratedCategory.movie, year: 2016),
    CuratedTitle('Get Out', CuratedCategory.movie, year: 2017),
    CuratedTitle('A Quiet Place', CuratedCategory.movie, year: 2018),
    CuratedTitle('A Quiet Place: Day One', CuratedCategory.movie, year: 2024),
    CuratedTitle('Once Upon a Time in Hollywood', CuratedCategory.movie, year: 2019),
    CuratedTitle('Knives Out', CuratedCategory.movie, year: 2019),
    CuratedTitle('Glass Onion', CuratedCategory.movie, year: 2022),
    CuratedTitle('Everything Everywhere All at Once', CuratedCategory.movie, spotlight: true, year: 2022),
    CuratedTitle('The Whale', CuratedCategory.movie, year: 2022),
    CuratedTitle('Tar', CuratedCategory.movie, year: 2022),
    CuratedTitle('The Banshees of Inisherin', CuratedCategory.movie, year: 2022),
    CuratedTitle('All Quiet on the Western Front', CuratedCategory.movie, alternativeNames: ['Im Westen nichts Neues'], year: 2022),
    CuratedTitle('The Zone of Interest', CuratedCategory.movie, year: 2023),
    CuratedTitle('Anatomy of a Fall', CuratedCategory.movie, year: 2023),
    CuratedTitle('Past Lives', CuratedCategory.movie, year: 2023),
    CuratedTitle('The Holdovers', CuratedCategory.movie, year: 2023),
    CuratedTitle('Maestro', CuratedCategory.movie, year: 2023),
    CuratedTitle('May December', CuratedCategory.movie, year: 2023),
    CuratedTitle('American Fiction', CuratedCategory.movie, year: 2023),
    CuratedTitle('The Color Purple', CuratedCategory.movie, year: 2023),
    CuratedTitle('Saltburn', CuratedCategory.movie, year: 2023),
    CuratedTitle('Priscilla', CuratedCategory.movie, year: 2023),
    CuratedTitle('Ferrari', CuratedCategory.movie, year: 2023),
    CuratedTitle('The Iron Claw', CuratedCategory.movie, year: 2023),
    CuratedTitle('Anyone But You', CuratedCategory.movie, year: 2023),
    CuratedTitle('Challengers', CuratedCategory.movie, year: 2024),
    CuratedTitle('Civil War', CuratedCategory.movie, year: 2024),
    CuratedTitle('The Fall Guy', CuratedCategory.movie, year: 2024),
    CuratedTitle('Twisters', CuratedCategory.movie, year: 2024),
    CuratedTitle('It Ends with Us', CuratedCategory.movie, year: 2024),
    CuratedTitle('Beetlejuice Beetlejuice', CuratedCategory.movie, year: 2024),
    CuratedTitle('Alien: Romulus', CuratedCategory.movie, year: 2024),
    CuratedTitle('Smile 2', CuratedCategory.movie, year: 2024),
    CuratedTitle('Terrifier 3', CuratedCategory.movie, year: 2024),
    CuratedTitle('Venom: The Last Dance', CuratedCategory.movie, year: 2024),
    CuratedTitle('Wicked', CuratedCategory.movie, year: 2024),
    CuratedTitle('Moana 2', CuratedCategory.movie, year: 2024),
    CuratedTitle('Kraven the Hunter', CuratedCategory.movie, year: 2024),
    CuratedTitle('Mufasa: The Lion King', CuratedCategory.movie, year: 2024),
    CuratedTitle('Sonic the Hedgehog 3', CuratedCategory.movie, year: 2024),

    // Horror & Thriller
    CuratedTitle('The Conjuring', CuratedCategory.movie, year: 2013),
    CuratedTitle('Hereditary', CuratedCategory.movie, year: 2018),
    CuratedTitle('Midsommar', CuratedCategory.movie, year: 2019),
    CuratedTitle('It', CuratedCategory.movie, alternativeNames: ['Es'], year: 2017),
    CuratedTitle('The Shining', CuratedCategory.movie, year: 1980),
    CuratedTitle('Nope', CuratedCategory.movie, year: 2022),
    CuratedTitle('Barbarian', CuratedCategory.movie, year: 2022),
    CuratedTitle('Pearl', CuratedCategory.movie, year: 2022),
    CuratedTitle('M3GAN', CuratedCategory.movie, year: 2022),
    CuratedTitle('Talk to Me', CuratedCategory.movie, year: 2023),
    CuratedTitle('The Nun II', CuratedCategory.movie, year: 2023),
    CuratedTitle('Five Nights at Freddy\'s', CuratedCategory.movie, year: 2023),
    CuratedTitle('The Exorcist: Believer', CuratedCategory.movie, year: 2023),
    CuratedTitle('Saw X', CuratedCategory.movie, year: 2023),
    CuratedTitle('Longlegs', CuratedCategory.movie, year: 2024),
    CuratedTitle('The Substance', CuratedCategory.movie, year: 2024),

    // Comedy
    CuratedTitle('The Hangover', CuratedCategory.movie, year: 2009),
    CuratedTitle('Superbad', CuratedCategory.movie, year: 2007),
    CuratedTitle('Bridesmaids', CuratedCategory.movie, year: 2011),
    CuratedTitle('The Grand Budapest Hotel', CuratedCategory.movie, year: 2014),
    CuratedTitle('Jojo Rabbit', CuratedCategory.movie, year: 2019),
    CuratedTitle('Free Guy', CuratedCategory.movie, year: 2021),
    CuratedTitle('The Menu', CuratedCategory.movie, year: 2022),
    CuratedTitle('Triangle of Sadness', CuratedCategory.movie, year: 2022),

    // Deutsche Filme
    CuratedTitle('Das Boot', CuratedCategory.movie, year: 1981),
    CuratedTitle('Good Bye, Lenin!', CuratedCategory.movie, year: 2003),
    CuratedTitle('Das Leben der Anderen', CuratedCategory.movie, alternativeNames: ['The Lives of Others'], year: 2006),
    CuratedTitle('Der Untergang', CuratedCategory.movie, alternativeNames: ['Downfall'], year: 2004),
    CuratedTitle('Lola rennt', CuratedCategory.movie, alternativeNames: ['Run Lola Run'], year: 1998),
    CuratedTitle('Toni Erdmann', CuratedCategory.movie, year: 2016),
    CuratedTitle('System Crasher', CuratedCategory.movie, alternativeNames: ['Systemsprenger'], year: 2019),
  ];

  // ============================================
  // KINDERFILME & FAMILIENFILME
  // ============================================
  static const List<CuratedTitle> kids = [
    // Disney/Pixar Klassiker (Spotlight-würdig)
    CuratedTitle('Frozen', CuratedCategory.kids, spotlight: true, alternativeNames: ['Die Eiskönigin', 'Frozen - Die Eiskönigin'], year: 2013),
    CuratedTitle('Frozen II', CuratedCategory.kids, spotlight: true, alternativeNames: ['Die Eiskönigin 2', 'Frozen 2'], year: 2019),
    CuratedTitle('Moana', CuratedCategory.kids, spotlight: true, alternativeNames: ['Vaiana'], year: 2016),
    CuratedTitle('Encanto', CuratedCategory.kids, spotlight: true, year: 2021),
    CuratedTitle('Coco', CuratedCategory.kids, spotlight: true, year: 2017),
    CuratedTitle('Inside Out', CuratedCategory.kids, spotlight: true, alternativeNames: ['Alles steht Kopf'], year: 2015),
    CuratedTitle('Inside Out 2', CuratedCategory.kids, spotlight: true, alternativeNames: ['Alles steht Kopf 2'], year: 2024),
    CuratedTitle('Turning Red', CuratedCategory.kids, spotlight: true, year: 2022),
    CuratedTitle('Luca', CuratedCategory.kids, spotlight: true, year: 2021),
    CuratedTitle('Soul', CuratedCategory.kids, spotlight: true, year: 2020),
    CuratedTitle('Elemental', CuratedCategory.kids, spotlight: true, year: 2023),
    CuratedTitle('Wish', CuratedCategory.kids, spotlight: true, year: 2023),

    // Pixar Klassiker
    CuratedTitle('Toy Story', CuratedCategory.kids, spotlight: true, year: 1995),
    CuratedTitle('Toy Story 2', CuratedCategory.kids, year: 1999),
    CuratedTitle('Toy Story 3', CuratedCategory.kids, year: 2010),
    CuratedTitle('Toy Story 4', CuratedCategory.kids, year: 2019),
    CuratedTitle('Finding Nemo', CuratedCategory.kids, spotlight: true, alternativeNames: ['Findet Nemo'], year: 2003),
    CuratedTitle('Finding Dory', CuratedCategory.kids, alternativeNames: ['Findet Dorie'], year: 2016),
    CuratedTitle('The Incredibles', CuratedCategory.kids, spotlight: true, alternativeNames: ['Die Unglaublichen'], year: 2004),
    CuratedTitle('Incredibles 2', CuratedCategory.kids, alternativeNames: ['Die Unglaublichen 2'], year: 2018),
    CuratedTitle('Monsters, Inc.', CuratedCategory.kids, alternativeNames: ['Die Monster AG'], year: 2001),
    CuratedTitle('Up', CuratedCategory.kids, alternativeNames: ['Oben'], year: 2009),
    CuratedTitle('WALL-E', CuratedCategory.kids, year: 2008),
    CuratedTitle('Ratatouille', CuratedCategory.kids, year: 2007),
    CuratedTitle('Cars', CuratedCategory.kids, year: 2006),
    CuratedTitle('Brave', CuratedCategory.kids, alternativeNames: ['Merida'], year: 2012),
    CuratedTitle('Onward', CuratedCategory.kids, alternativeNames: ['Onward: Keine halben Sachen'], year: 2020),
    CuratedTitle('Lightyear', CuratedCategory.kids, year: 2022),

    // Disney Klassiker
    CuratedTitle('The Lion King', CuratedCategory.kids, spotlight: true, alternativeNames: ['Der König der Löwen'], year: 1994),
    CuratedTitle('The Little Mermaid', CuratedCategory.kids, spotlight: true, alternativeNames: ['Arielle', 'Die kleine Meerjungfrau'], year: 1989),
    CuratedTitle('Aladdin', CuratedCategory.kids, spotlight: true, year: 1992),
    CuratedTitle('Beauty and the Beast', CuratedCategory.kids, alternativeNames: ['Die Schöne und das Biest'], year: 1991),
    CuratedTitle('Tangled', CuratedCategory.kids, spotlight: true, alternativeNames: ['Rapunzel'], year: 2010),
    CuratedTitle('Zootopia', CuratedCategory.kids, spotlight: true, alternativeNames: ['Zoomania'], year: 2016),
    CuratedTitle('Big Hero 6', CuratedCategory.kids, alternativeNames: ['Baymax'], year: 2014),
    CuratedTitle('Wreck-It Ralph', CuratedCategory.kids, alternativeNames: ['Ralph reichts'], year: 2012),
    CuratedTitle('Ralph Breaks the Internet', CuratedCategory.kids, alternativeNames: ['Chaos im Netz'], year: 2018),
    CuratedTitle('Raya and the Last Dragon', CuratedCategory.kids, alternativeNames: ['Raya und der letzte Drache'], year: 2021),
    CuratedTitle('Strange World', CuratedCategory.kids, year: 2022),

    // DreamWorks
    CuratedTitle('Shrek', CuratedCategory.kids, spotlight: true, year: 2001),
    CuratedTitle('Shrek 2', CuratedCategory.kids, year: 2004),
    CuratedTitle('How to Train Your Dragon', CuratedCategory.kids, spotlight: true, alternativeNames: ['Drachenzähmen leicht gemacht'], year: 2010),
    CuratedTitle('Kung Fu Panda', CuratedCategory.kids, spotlight: true, year: 2008),
    CuratedTitle('Kung Fu Panda 4', CuratedCategory.kids, year: 2024),
    CuratedTitle('Madagascar', CuratedCategory.kids, year: 2005),
    CuratedTitle('The Boss Baby', CuratedCategory.kids, year: 2017),
    CuratedTitle('Trolls', CuratedCategory.kids, year: 2016),
    CuratedTitle('Trolls Band Together', CuratedCategory.kids, year: 2023),
    CuratedTitle('Puss in Boots', CuratedCategory.kids, alternativeNames: ['Der gestiefelte Kater'], year: 2011),
    CuratedTitle('Puss in Boots: The Last Wish', CuratedCategory.kids, spotlight: true, alternativeNames: ['Der gestiefelte Kater: Der letzte Wunsch'], year: 2022),
    CuratedTitle('The Bad Guys', CuratedCategory.kids, alternativeNames: ['Die Bad Guys'], year: 2022),
    CuratedTitle('Migration', CuratedCategory.kids, year: 2023),

    // Illumination
    CuratedTitle('Despicable Me', CuratedCategory.kids, spotlight: true, alternativeNames: ['Ich - Einfach unverbesserlich', 'Minions'], year: 2010),
    CuratedTitle('Despicable Me 2', CuratedCategory.kids, alternativeNames: ['Ich - Einfach unverbesserlich 2'], year: 2013),
    CuratedTitle('Despicable Me 3', CuratedCategory.kids, alternativeNames: ['Ich - Einfach unverbesserlich 3'], year: 2017),
    CuratedTitle('Despicable Me 4', CuratedCategory.kids, alternativeNames: ['Ich - Einfach unverbesserlich 4'], year: 2024),
    CuratedTitle('Minions', CuratedCategory.kids, spotlight: true, year: 2015),
    CuratedTitle('Minions: The Rise of Gru', CuratedCategory.kids, alternativeNames: ['Minions - Auf der Suche nach dem Mini-Boss'], year: 2022),
    CuratedTitle('The Secret Life of Pets', CuratedCategory.kids, alternativeNames: ['Pets'], year: 2016),
    CuratedTitle('Sing', CuratedCategory.kids, year: 2016),
    CuratedTitle('Sing 2', CuratedCategory.kids, year: 2021),
    CuratedTitle('The Super Mario Bros. Movie', CuratedCategory.kids, spotlight: true, alternativeNames: ['Der Super Mario Bros. Film'], year: 2023),

    // Sony Animation
    CuratedTitle('Spider-Man: Into the Spider-Verse', CuratedCategory.kids, spotlight: true, year: 2018),
    CuratedTitle('Spider-Man: Across the Spider-Verse', CuratedCategory.kids, spotlight: true, year: 2023),
    CuratedTitle('Hotel Transylvania', CuratedCategory.kids, year: 2012),
    CuratedTitle('The Mitchells vs. the Machines', CuratedCategory.kids, year: 2021),
    CuratedTitle('Cloudy with a Chance of Meatballs', CuratedCategory.kids, alternativeNames: ['Wolkig mit Aussicht auf Fleischbällchen'], year: 2009),

    // Andere Studios
    CuratedTitle('Paddington', CuratedCategory.kids, spotlight: true, year: 2014),
    CuratedTitle('Paddington 2', CuratedCategory.kids, spotlight: true, year: 2017),
    CuratedTitle('Wonka', CuratedCategory.kids, spotlight: true, year: 2023),
    CuratedTitle('The Lego Movie', CuratedCategory.kids, year: 2014),
    CuratedTitle('The Lego Batman Movie', CuratedCategory.kids, year: 2017),
    CuratedTitle('IF', CuratedCategory.kids, year: 2024),
    CuratedTitle('Garfield', CuratedCategory.kids, year: 2024),
    CuratedTitle('Harold and the Purple Crayon', CuratedCategory.kids, year: 2024),

    // Anime für Kinder
    CuratedTitle('My Neighbor Totoro', CuratedCategory.kids, spotlight: true, alternativeNames: ['Mein Nachbar Totoro'], year: 1988),
    CuratedTitle('Spirited Away', CuratedCategory.kids, spotlight: true, alternativeNames: ['Chihiros Reise ins Zauberland'], year: 2001),
    CuratedTitle('Howl\'s Moving Castle', CuratedCategory.kids, alternativeNames: ['Das wandelnde Schloss'], year: 2004),
    CuratedTitle('Ponyo', CuratedCategory.kids, year: 2008),
    CuratedTitle('The Boy and the Heron', CuratedCategory.kids, spotlight: true, alternativeNames: ['Der Junge und der Reiher'], year: 2023),
    CuratedTitle('Suzume', CuratedCategory.kids, year: 2022),
    CuratedTitle('Your Name', CuratedCategory.kids, alternativeNames: ['Kimi no Na wa'], year: 2016),
    CuratedTitle('Weathering with You', CuratedCategory.kids, year: 2019),
  ];

  // ============================================
  // DOKUMENTATIONEN
  // ============================================
  static const List<CuratedTitle> documentaries = [
    CuratedTitle('Planet Earth', CuratedCategory.documentary, spotlight: true, alternativeNames: ['Unser Planet'], year: 2006),
    CuratedTitle('Planet Earth II', CuratedCategory.documentary, spotlight: true, year: 2016),
    CuratedTitle('Planet Earth III', CuratedCategory.documentary, spotlight: true, year: 2023),
    CuratedTitle('Our Planet', CuratedCategory.documentary, spotlight: true, year: 2019),
    CuratedTitle('Blue Planet', CuratedCategory.documentary, year: 2001),
    CuratedTitle('Blue Planet II', CuratedCategory.documentary, year: 2017),
    CuratedTitle('The Last Dance', CuratedCategory.documentary, spotlight: true, year: 2020),
    CuratedTitle('Making a Murderer', CuratedCategory.documentary, year: 2015),
    CuratedTitle('Tiger King', CuratedCategory.documentary, year: 2020),
    CuratedTitle('The Social Dilemma', CuratedCategory.documentary, year: 2020),
    CuratedTitle('Free Solo', CuratedCategory.documentary, year: 2018),
    CuratedTitle('My Octopus Teacher', CuratedCategory.documentary, year: 2020),
    CuratedTitle('The Beatles: Get Back', CuratedCategory.documentary, year: 2021),
    CuratedTitle('Formula 1: Drive to Survive', CuratedCategory.documentary, year: 2019),
    CuratedTitle('Welcome to Wrexham', CuratedCategory.documentary, year: 2022),
    CuratedTitle('The Tinder Swindler', CuratedCategory.documentary, year: 2022),
    CuratedTitle('Don\'t Pick Up the Phone', CuratedCategory.documentary, year: 2022),
    CuratedTitle('The Deepest Breath', CuratedCategory.documentary, year: 2023),
    CuratedTitle('Arnold', CuratedCategory.documentary, year: 2023),
    CuratedTitle('Beckham', CuratedCategory.documentary, year: 2023),
  ];

  // ============================================
  // ALLE TITEL KOMBINIERT
  // ============================================
  static List<CuratedTitle> get all => [...series, ...movies, ...kids, ...documentaries];

  /// Nur Spotlight-fähige Titel
  static List<CuratedTitle> get spotlightTitles => all.where((t) => t.spotlight).toList();

  /// Titel nach Kategorie filtern
  static List<CuratedTitle> byCategory(CuratedCategory category) =>
      all.where((t) => t.category == category).toList();

  /// Titel suchen (case-insensitive)
  static CuratedTitle? findByName(String name) {
    final normalized = name.toLowerCase().trim();
    for (final title in all) {
      if (title.name.toLowerCase() == normalized) return title;
      for (final alt in title.alternativeNames) {
        if (alt.toLowerCase() == normalized) return title;
      }
    }
    return null;
  }

  /// Prüft ob ein Name (teilweise) mit einem kuratierten Titel übereinstimmt
  /// Gibt den besten Match zurück mit Score (0.0-1.0)
  static (CuratedTitle?, double) findBestMatch(String cleanName) {
    if (cleanName.isEmpty) return (null, 0.0);

    final normalized = cleanName.toLowerCase().trim();
    CuratedTitle? bestMatch;
    double bestScore = 0.0;

    for (final title in all) {
      // Exakter Match
      final titleLower = title.name.toLowerCase();
      if (normalized == titleLower) {
        return (title, 1.0);
      }

      // Alternative Namen prüfen
      for (final alt in title.alternativeNames) {
        if (normalized == alt.toLowerCase()) {
          return (title, 1.0);
        }
      }

      // Prefix-Match (z.B. "Breaking Bad S01E01" matched "Breaking Bad")
      if (normalized.startsWith(titleLower)) {
        final afterTitle = normalized.substring(titleLower.length).trim();
        // Muss mit Leerzeichen, Zahl oder Sonderzeichen weitergehen
        if (afterTitle.isEmpty ||
            afterTitle.startsWith(RegExp(r'[\s\d\-:\(\[]'))) {
          final score = titleLower.length / normalized.length;
          if (score > bestScore && score >= 0.5) {
            bestScore = score;
            bestMatch = title;
          }
        }
      }

      // Alternative Namen als Prefix
      for (final alt in title.alternativeNames) {
        final altLower = alt.toLowerCase();
        if (normalized.startsWith(altLower)) {
          final afterTitle = normalized.substring(altLower.length).trim();
          if (afterTitle.isEmpty ||
              afterTitle.startsWith(RegExp(r'[\s\d\-:\(\[]'))) {
            final score = altLower.length / normalized.length;
            if (score > bestScore && score >= 0.5) {
              bestScore = score;
              bestMatch = title;
            }
          }
        }
      }

      // Contains-Match für kurze Titel (mindestens 70% Überlappung)
      if (titleLower.length >= 5) {
        if (normalized.contains(titleLower)) {
          final score = titleLower.length / normalized.length;
          if (score > bestScore && score >= 0.6) {
            bestScore = score * 0.9; // Leicht niedriger als Prefix-Match
            bestMatch = title;
          }
        }
      }
    }

    return (bestMatch, bestScore);
  }
}
