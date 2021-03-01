from typing import Set, Dict, List, NamedTuple
from examples.reading_comprehension.utils.wiki_link_db import WikiLinkDB
import joblib
from transformers.tokenization_utils import PreTrainedTokenizer
from luke.utils.entity_vocab import EntityVocab
from luke.utils.interwiki_db import InterwikiDB
from examples.utils.entity_db import EntityDB

from allennlp.data import Token


class Mention(NamedTuple):
    entity: str
    start: int
    end: int


class WikiMentionDetector:
    """
    Detect entity mentions in text from Wikipedia articles.
    """

    def __init__(
        self,
        tokenizer: PreTrainedTokenizer,
        wiki_link_db_path: str,
        model_redirect_mappings_path: str,
        link_redirect_mappings_path: str,
        inter_wiki_path: str,
        entity_vocab_path: str,
        multilingual_entity_db_path: Dict[str, str],
        min_mention_link_prob: float = 0.01,
        max_mention_length: int = 10,
    ):
        self.tokenizer = tokenizer
        self.wiki_link_db = WikiLinkDB(wiki_link_db_path)
        self.model_redirect_mappings: Dict[str, str] = joblib.load(model_redirect_mappings_path)
        self.link_redirect_mappings: Dict[str, str] = joblib.load(link_redirect_mappings_path)
        self.inter_wiki_db = InterwikiDB.load(inter_wiki_path)

        self.entity_vocab = EntityVocab(entity_vocab_path)

        self.entity_db_dict = {lang: EntityDB(path) for lang, path in multilingual_entity_db_path.items()}

        self.min_mention_link_prob = min_mention_link_prob

        self.max_mention_length = max_mention_length

    def get_mention_candidates(self, title: str) -> Dict[str, str]:
        """
        Returns a dict of [mention, entity (title)]
        """
        title = self.link_redirect_mappings.get(title, title)

        # mention_to_entity
        mention_candidates: Dict[str, str] = {}
        ambiguous_mentions: Set[str] = set()

        for link in self.wiki_link_db.get(title):
            if link.link_prob < self.min_mention_link_prob:
                continue

            link_text = self._normalize_mention(link.text)
            if link_text in mention_candidates and mention_candidates[link_text] != link.title:
                ambiguous_mentions.add(link_text)
                continue

            mention_candidates[link_text] = link.title

        for link_text in ambiguous_mentions:
            del mention_candidates[link_text]
        return mention_candidates

    def detect_mentions(self, tokens: List[str], mention_candidates: Dict[str, str], language: str) -> List[Mention]:
        mentions = []
        cur = 0
        for start, token in enumerate(tokens):
            if start < cur:
                continue

            for end in range(min(start + self.max_mention_length, len(tokens)), start, -1):

                mention_text = self.tokenizer.convert_tokens_to_string(tokens[start:end])
                mention_text = self._normalize_mention(mention_text)
                if mention_text in mention_candidates:
                    cur = end
                    title = mention_candidates[mention_text]
                    title = self.model_redirect_mappings.get(title, title)  # resolve mismatch between two dumps
                    if self.entity_vocab.contains(title, language):
                        mention = Mention(self.entity_vocab[title], start, end)
                        mentions.append(mention)
                    break

        return mentions

    def __call__(self, tokens: List[Token], title: str, language: str):
        en_mention_candidates = self.get_mention_candidates(title)
        en_entities = list(en_mention_candidates.values())

        target_entities = []
        for ent in en_entities:
            translated_ent = self.inter_wiki_db.get_title_translation(ent, "en", language)
            if translated_ent is not None:
                target_entities.append(translated_ent)

        target_mention_candidates = {}
        for target_entity in target_entities:
            for entity, mention, count in self.entity_db_dict[language].query(target_entity):
                target_mention_candidates[mention] = entity

        target_mentions = self.detect_mentions(tokens, target_mention_candidates, language)

        return target_mentions

    @staticmethod
    def _normalize_mention(text: str):
        return " ".join(text.lower().split(" ")).strip()
