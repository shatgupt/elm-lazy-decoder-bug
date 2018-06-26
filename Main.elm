module Main exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import Json.Decode as JD
import Json.Decode.Extra exposing ((|:))


-- from elm-community/json-extra


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



-- (JD.lazy
--     (\_ ->
--         nodeDecoder
--             |> JD.andThen (\n -> JD.succeed (Root n))
--     )
-- )


foo : Tree
foo =
    Root
        { data = 2
        , children = []
        }


main =
    Html.program
        { init = init foo
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type alias Model =
    { tree : Tree
    }


init : Tree -> ( Model, Cmd Msg )
init t =
    ( Model t
    , getJson
    )



-- UPDATE


type Msg
    = GotJSON (Result Http.Error Tree)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotJSON (Ok newTree) ->
            Debug.log "model" ( Model newTree, Cmd.none )

        GotJSON (Err _) ->
            Debug.log "ERROR!" ( model, Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ pre [ style [ ( "width", "300" ) ] ]
            [ text (toString model) ]
        ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- HTTP


getJson : Cmd Msg
getJson =
    Http.send GotJSON
        (Http.get "http://127.0.0.1:9000/tree.json" treeDecoder)
