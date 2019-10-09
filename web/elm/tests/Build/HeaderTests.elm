module Build.HeaderTests exposing (all)

import Application.Models exposing (Session)
import Build.Header.Header as Header
import Build.Header.Models as Models
import Build.Header.Views as Views
import Build.StepTree.Models as STModels
import Common
import Concourse
import Concourse.BuildStatus exposing (BuildStatus(..))
import Expect
import HoverState
import Message.Callback as Callback
import Message.Effects as Effects
import Message.Message as Message
import Message.Subscription as Subscription
import RemoteData
import ScreenSize
import Set
import Test exposing (Test, describe, test)
import Time
import UserState


all : Test
all =
    describe "build page header"
        [ describe "title"
            [ test "is 'build' on a one-off build page" <|
                \_ ->
                    Header.header session model
                        |> .leftWidgets
                        |> Common.contains (Views.Title "0" Nothing)
            ]
        , describe "duration"
            [ test "pending build has no duration" <|
                \_ ->
                    Header.header session
                        { model
                            | duration =
                                { startedAt = Nothing
                                , finishedAt = Nothing
                                }
                        }
                        |> .leftWidgets
                        |> Common.contains
                            (Views.Duration <| Views.Pending)
            , test "running build has running time" <|
                \_ ->
                    Header.header session
                        { model
                            | duration =
                                { startedAt = Just <| Time.millisToPosix 0
                                , finishedAt = Nothing
                                }
                        }
                        |> .leftWidgets
                        |> Common.contains
                            (Views.Duration <|
                                Views.Running <|
                                    Views.Absolute "Jan 1 1970 12:00:00 AM" Nothing
                            )
            , test "cancelled build has cancelled duration" <|
                \_ ->
                    Header.header session
                        { model
                            | duration =
                                { startedAt = Nothing
                                , finishedAt = Just <| Time.millisToPosix 0
                                }
                        }
                        |> .leftWidgets
                        |> Common.contains
                            (Views.Duration <|
                                Views.Cancelled <|
                                    Views.Absolute "Jan 1 1970 12:00:00 AM" Nothing
                            )
            , test "finished build has duration" <|
                \_ ->
                    Header.header session
                        { model
                            | duration =
                                { startedAt = Just <| Time.millisToPosix 0
                                , finishedAt = Just <| Time.millisToPosix 1000
                                }
                        }
                        |> .leftWidgets
                        |> Common.contains
                            (Views.Duration <|
                                Views.Finished
                                    { started =
                                        Views.Absolute "Jan 1 1970 12:00:00 AM" Nothing
                                    , finished =
                                        Views.Absolute "Jan 1 1970 12:00:01 AM" Nothing
                                    , duration = Views.JustSeconds 1
                                    }
                            )
            ]
        , describe "buttons"
            [ test "re-run button does not appear on non-running one-off build" <|
                \_ ->
                    Header.header session
                        { model | status = BuildStatusSucceeded }
                        |> .rightWidgets
                        |> Common.notContains
                            (Views.Button <|
                                Just
                                    { type_ = Views.Rerun
                                    , isClickable = True
                                    , backgroundShade = Views.Light
                                    , backgroundColor = BuildStatusSucceeded
                                    , tooltip = False
                                    }
                            )
            , test "re-run button appears on non-running job build" <|
                \_ ->
                    Header.header session
                        { model | status = BuildStatusSucceeded, job = Just jobId }
                        |> .rightWidgets
                        |> Common.contains
                            (Views.Button <|
                                Just
                                    { type_ = Views.Rerun
                                    , isClickable = True
                                    , backgroundShade = Views.Light
                                    , backgroundColor = BuildStatusSucceeded
                                    , tooltip = False
                                    }
                            )
            -- TODO write this test at an appropriate level of integration
            -- , test "re-run button is hoverable" <|
            --     \_ ->
            --         ( { model | status = BuildStatusSucceeded, job = Just jobId }
            --         , []
            --         )
            --             |> Header.update
            --                 (Message.Hover <|
            --                     Just Message.RerunBuildButton
            --                 )
            --             |> Tuple.first
            --             |> Header.header session
            --             |> .rightWidgets
            --             |> Common.contains
            --                 (Views.Button <|
            --                     Just
            --                         { type_ = Views.Rerun
            --                         , isClickable = True
            --                         , backgroundShade = Views.Dark
            --                         , backgroundColor = BuildStatusSucceeded
            --                         , tooltip = False
            --                         }
            --                 )
            , test "clicking re-run button sends RerunJobBuild API call" <|
                \_ ->
                    ( { model | status = BuildStatusSucceeded, job = Just jobId }
                    , []
                    )
                        |> Header.update (Message.Click Message.RerunBuildButton)
                        |> Tuple.second
                        |> Common.contains
                            (Effects.RerunJobBuild <|
                                { teamName = "team"
                                , pipelineName = "pipeline"
                                , jobName = "job"
                                , buildName = model.name
                                }
                            )
            ]
        , test "stops fetching history once current build appears" <|
            \_ ->
                ( model, [] )
                    |> Header.handleCallback
                        (Callback.BuildFetched <| Ok build)
                    |> Header.handleCallback
                        (Callback.BuildHistoryFetched <|
                            Ok
                                { content = [ build ]
                                , pagination =
                                    { previousPage = Nothing
                                    , nextPage = Nothing
                                    }
                                }
                        )
                    |> Tuple.second
                    |> Common.notContains (Effects.FetchBuildHistory jobId Nothing)
        , test "status event from wrong build is discarded" <|
            \_ ->
                ( model, [] )
                    |> Header.handleCallback
                        (Callback.BuildFetched <| Ok build)
                    |> Header.handleDelivery
                        (Subscription.EventsReceived <|
                            Ok
                                [ { data = STModels.BuildStatus BuildStatusStarted <| Time.millisToPosix 0
                                  , url = "http://localhost:8080/api/v1/builds/1/events"
                                  }
                                ]
                        )
                    |> Tuple.first
                    |> Header.header session
                    |> .backgroundColor
                    |> Expect.equal BuildStatusPending
        ]


session : Session
session =
    { expandedTeams = Set.empty
    , pipelines = RemoteData.NotAsked
    , hovered = HoverState.NoHover
    , isSideBarOpen = False
    , screenSize = ScreenSize.Desktop
    , userState = UserState.UserStateLoggedOut
    , clusterName = ""
    , turbulenceImgSrc = ""
    , notFoundImgSrc = ""
    , csrfToken = ""
    , authToken = ""
    , pipelineRunningKeyframes = ""
    , timeZone = Time.utc
    }


model : Models.Model {}
model =
    { id = 0
    , name = "0"
    , job = Nothing
    , scrolledToCurrentBuild = False
    , history = []
    , duration = { startedAt = Nothing, finishedAt = Nothing }
    , status = BuildStatusPending
    , disableManualTrigger = False
    , now = Nothing
    , fetchingHistory = False
    , nextPage = Nothing
    , previousTriggerBuildByKey = False -- TODO WTF variable name
    }


build : Concourse.Build
build =
    { id = 0
    , name = "4"
    , job = Just jobId
    , status = model.status
    , duration = model.duration
    , reapTime = Nothing
    }


jobId : Concourse.JobIdentifier
jobId =
    { teamName = "team"
    , pipelineName = "pipeline"
    , jobName = "job"
    }
