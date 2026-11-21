// Experimental patch for one exact MIT-licensed Godot source revision.
// This does not change the pinned runtime or apply itself to the engine tree.
import {createHash} from 'node:crypto';
export const SCRIPT_ITERATOR_SOURCE_SHA256='713f2735f3cd0e0ccbe7f03a22cccfb3c3fafbd1543b5ed0c76d6565f034631b';
export function patchScriptIterator(source){
 if(createHash('sha256').update(source).digest('hex')!==SCRIPT_ITERATOR_SOURCE_SHA256)throw Error('Expected exact unmodified Godot ed1daf0bf script iterator');
 const replace=(before,after)=>{if(source.split(before).length!==2)throw Error('Patch context is not unique');source=source.replace(before,after);};
 replace('emoji_stack = static_cast<EmojiSubrunEntry *>(memalloc(emoji_size * sizeof(EmojiSubrunEntry)));','emoji_stack = static_cast<EmojiSubrunEntry *>(memalloc(emoji_size * sizeof(EmojiSubrunEntry)));\n\t\t\t\t\t\t\tmemcpy(emoji_stack, starter_emoji_stack, sizeof(starter_emoji_stack));');
 replace('paren_stack = static_cast<ParenStackEntry *>(memalloc(paren_size * sizeof(ParenStackEntry)));','paren_stack = static_cast<ParenStackEntry *>(memalloc(paren_size * sizeof(ParenStackEntry)));\n\t\t\t\t\t\t\tmemcpy(paren_stack, starter_paren_stack, sizeof(starter_paren_stack));');
 replace('\t\tif (emoji_stack != starter_emoji_stack) {\n\t\t\tmemfree(emoji_stack);\n\t\t}\n\t} while (script_end < p_length);','\t} while (script_end < p_length);\n\n\tif (emoji_stack != starter_emoji_stack) {\n\t\tmemfree(emoji_stack);\n\t}');
 replace('\t\t\tif (U_FAILURE(err)) {\n\t\t\t\tif (paren_stack != starter_paren_stack)', '\t\t\tif (U_FAILURE(err)) {\n\t\t\t\tif (emoji_stack != starter_emoji_stack) {\n\t\t\t\t\tmemfree(emoji_stack);\n\t\t\t\t}\n\t\t\t\tif (paren_stack != starter_paren_stack)');
 return source;
}
