import Foundation

var itemOne = HNItem(id: 123,
                   title: "This is a story with a particularly long title that I built in one day",
                   storyLink: URL(string: "https://www.example.com")!,
                   domain: "example.com",
                   age: "2 hours ago",
                   author: "ejdyksen",
                   score: 123,
                   commentCount: 123)



var itemTwo = HNItem(id: 456,
                   title: "This is also a story",
                   storyLink: URL(string: "https://www.example.com")!,
                   domain: "example.com",
                   age: "3 hours ago",
                   author: "ejdyksen",
                   score: 123,
                   commentCount: 555)

let sampleItems = [itemOne, itemTwo, itemOne, itemTwo, itemOne, itemTwo, itemOne, itemTwo]

extension HNListing {
    static func exampleService() -> HNListing {
        let service = HNListing(.news)
        service.items = sampleItems
        return service
    }
}

let longStringOne = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed ne, dum huic obsequor, vobis molestus sim. Itaque eos id agere, ut a se dolores, morbos, debilitates repellant. Duo Reges: constructio interrete. Optime, inquam. Sed ne, dum huic obsequor, vobis molestus sim. Duarum enim vitarum nobis erunt instituta capienda. Vidit Homerus probari fabulam non posse, si cantiunculis tantus irretitus vir teneretur; Conclusum est enim contra Cyrenaicos satis acute, nihil ad Epicurum. Ita credo. Te enim iudicem aequum puto, modo quae dicat ille bene noris."
let longStringTwo = "Quid enim est a Chrysippo praetermissum in Stoicis? Quicquid enim a sapientia proficiscitur, id continuo debet expletum esse omnibus suis partibus; Ac ne plura complectar-sunt enim innumerabilia-, bene laudata virtus voluptatis aditus intercludat necesse est. Nam cui proposito sit conservatio sui, necesse est huic partes quoque sui caras suo genere laudabiles. Atque hoc loco similitudines eas, quibus illi uti solent, dissimillimas proferebas. Summus dolor plures dies manere non potest? Ut necesse sit omnium rerum, quae natura vigeant, similem esse finem, non eundem. Sic consequentibus vestris sublatis prima tolluntur. An haec ab eo non dicuntur? Tu quidem reddes"

let comment1 = HNComment(id: 1, author: "ejd", age: "1 hour ago", indentLevel: 0, paragraphs: ["This is the first part of the comment", longStringOne, "The end"])
var comment2 = HNComment(id: 2, author: "ejdyksen", age: "1 hour ago", indentLevel: 0, paragraphs: [longStringTwo])
var comment3 = HNComment(id: 3, author: "zepherhillis", age: "1 hour ago", indentLevel: 0, paragraphs: [longStringOne])
let comment4 = HNComment(id: 4, author: "ejd", age: "1 hour ago", indentLevel: 0, paragraphs: [longStringTwo])
let comment5 = HNComment(id: 5, author: "ejd", age: "1 hour ago", indentLevel: 0, paragraphs: [longStringOne])
let comment6 = HNComment(id: 6, author: "ejd", age: "1 hour ago", indentLevel: 0, paragraphs: [longStringTwo])
let comment7 = HNComment(id: 7, author: "ejd", age: "1 hour ago", indentLevel: 1, paragraphs: [longStringOne])
let comment8 = HNComment(id: 8, author: "ejd", age: "1 hour ago", indentLevel: 1, paragraphs: [longStringTwo])

extension HNComment {
    static func itemWithComments() -> HNItem {
        let itemWithComments = itemOne
        itemWithComments.rootComments = [comment1, comment2, comment3, comment4, comment5, comment6]
        comment1.children = [comment7, comment8]
        itemWithComments.paragraphs = ["This is the text of my story. It might not be much, but it's mine, and that's good enough for me.", "Thanks, everyone"]

        return itemWithComments
    }
}
