### Repro for a possible bug in Elm using recursive lazy decoder

For a recursive JSON decoder with `lazy` evaluation, Elm is generating decoders in wrong order causing error:
```js
Uncaught TypeError: Cannot read property 'tag' of undefined
    at runHelp (main.elm:5822)
```
See below for a [workaround](#Workaround).

### Repro Steps
1. Clone this repo: `git clone https://github.com/shatgupt/elm-lazy-decoder-bug.git`
2. Compile into HTML: `elm-make Main.elm --output=index.html`
3. Start static file server for getting JSON: `python -m SimpleHTTPServer 9000`
4. Open `http://127.0.0.1:9000/` in your browser and check developer console. You will see an error like:
    ```js
    Uncaught TypeError: Cannot read property 'tag' of undefined
    at runHelp ((index):5798)
    ```
5. Open the generated `index.html` in an editor, find `treeDecoder`(around line 9335) and move it below `nodeDecoder`. The section should now look like below:
    ```js
    var _shatgupt$elm_lazy_decoder_bug$Main$nodeDecoder = A2(
        ...
                _elm_lang$core$Json_Decode$lazy(
                    function (_p1) {
                        return _shatgupt$elm_lazy_decoder_bug$Main$treeDecoder;
                    }))));
    var _shatgupt$elm_lazy_decoder_bug$Main$treeDecoder = A2(
        ...
            _shatgupt$elm_lazy_decoder_bug$Main$nodeDecoder));
    var _shatgupt$elm_lazy_decoder_bug$Main$foo = _shatgupt$elm_lazy_decoder_bug$Main$Root(
    ```
6. Reload `http://127.0.0.1:9000/` in your browser and you should see updated model from `tree.json` on the page and no error in console.

## Explanation
### Decoder (See [Main.elm](Main.elm) for complete example)
```elm
import Json.Decode as JD
import Json.Decode.Extra exposing ((|:)) -- from elm-community/json-extra

type alias Node =
    { data : Int
    , children : List Tree
    }


type Tree
    = Root Node


nodeDecoder : JD.Decoder Node
nodeDecoder =
    JD.succeed Node
        |: JD.field "data" JD.int
        |: JD.field "children"
            (JD.list (JD.lazy (\_ -> treeDecoder)))


treeDecoder : JD.Decoder Tree
treeDecoder =
    JD.at [ "Root" ]
        (nodeDecoder
            |> JD.andThen (\n -> JD.succeed (Root n))
        )
```

After running `elm-make Main.elm --output=index.html`, the generated file has decoders in the order:
```js
var _shatgupt$elm_lazy_decoder_bug$Main$treeDecoder = A2(
	_elm_lang$core$Json_Decode$at,
	{
		ctor: '::',
		_0: 'Root',
		_1: {ctor: '[]'}
	},
	A2(
		_elm_lang$core$Json_Decode$andThen,
		function (n) {
			return _elm_lang$core$Json_Decode$succeed(
				_shatgupt$elm_lazy_decoder_bug$Main$Root(n));
		},
		_shatgupt$elm_lazy_decoder_bug$Main$nodeDecoder));
var _shatgupt$elm_lazy_decoder_bug$Main$nodeDecoder = A2(
	_elm_community$json_extra$Json_Decode_Extra_ops['|:'],
	A2(
		_elm_community$json_extra$Json_Decode_Extra_ops['|:'],
		_elm_lang$core$Json_Decode$succeed(_shatgupt$elm_lazy_decoder_bug$Main$Node),
		A2(_elm_lang$core$Json_Decode$field, 'data', _elm_lang$core$Json_Decode$int)),
	A2(
		_elm_lang$core$Json_Decode$field,
		'children',
		_elm_lang$core$Json_Decode$list(
			_elm_lang$core$Json_Decode$lazy(
				function (_p1) {
					return _shatgupt$elm_lazy_decoder_bug$Main$treeDecoder;
				}))));
```
whereas it should have been `nodeDecoder` first and then `treeDecoder` because `treeDecoder` is referencing `nodeDecoder` immediately(non-lazily). Changing the order manually solves it.

### Workaround
Makind the `treeDecoder` also lazily evaluate `nodeDecoder` solves the problem for now.
```elm
treeDecoder : JD.Decoder Tree
treeDecoder =
    JD.at [ "Root" ]
        (JD.lazy
            (\_ ->
                nodeDecoder
                    |> JD.andThen (\n -> JD.succeed (Root n))
            )
        )
```
