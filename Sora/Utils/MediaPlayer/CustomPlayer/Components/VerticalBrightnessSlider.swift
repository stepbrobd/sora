//
//  VerticalBrightnessSlider.swift
//  Custom Brighness bar
//
//  Created by Pratik on 08/01/23.
//  Modified to update screen brightness when used as a brightness slider.
//

import SwiftUI

struct VerticalBrightnessSlider<T: BinaryFloatingPoint>: View {
    @Binding var value: T
    let inRange: ClosedRange<T>
    let activeFillColor: Color
    let fillColor: Color
    let emptyColor: Color
    let width: CGFloat
    let onEditingChanged: (Bool) -> Void
    
    // private variables
    @State private var localRealProgress: T = 0
    @State private var localTempProgress: T = 0
    @GestureState private var isActive: Bool = false
    
    var body: some View {
        GeometryReader { bounds in
            ZStack {
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: isActive ? width : width/2, style: .continuous)
                            .fill(emptyColor)
                        RoundedRectangle(cornerRadius: isActive ? width : width/2, style: .continuous)
                            .fill(isActive ? activeFillColor : fillColor)
                            .mask({
                                VStack {
                                    Spacer(minLength: 0)
                                    Rectangle()
                                        .frame(height: max(geo.size.height * CGFloat((localRealProgress + localTempProgress)), 0),
                                               alignment: .leading)
                                }
                            })
                        
                        Image(systemName: getIconName)
                            .font(.system(size: isActive ? 16 : 12, weight: .medium, design: .rounded))
                            .foregroundColor(isActive ? fillColor : Color.white) // bright white when not active
                            .animation(.spring(), value: isActive)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                            .padding(.bottom)
                            .overlay {
                                Image(systemName: getIconName)
                                    .font(.system(size: isActive ? 16 : 12, weight: .medium, design: .rounded))
                                    .foregroundColor(isActive ? Color.gray : Color.white.opacity(0.8))
                                    .animation(.spring(), value: isActive)
                                    .frame(maxHeight: .infinity, alignment: .bottom)
                                    .padding(.bottom)
                                    .mask {
                                        VStack {
                                            Spacer(minLength: 0)
                                            Rectangle()
                                                .frame(height: max(geo.size.height * CGFloat((localRealProgress + localTempProgress)), 0),
                                                       alignment: .leading)
                                        }
                                    }
                            }
                            //.frame(maxWidth: isActive ? .infinity : 0)
                           // .opacity(isActive ? 1 : 0)
                    }
                    .clipped()
                }
                .frame(height: isActive ? bounds.size.height * 1.15 : bounds.size.height, alignment: .center)
    //            .shadow(color: .black.opacity(0.1), radius: isActive ? 20 : 0, x: 0, y: 0)
                .animation(animation, value: isActive)
            }
            .frame(width: bounds.size.width, height: bounds.size.height, alignment: .center)
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .updating($isActive) { value, state, transaction in
                    state = true
                }
                .onChanged { gesture in
                    localTempProgress = T(-gesture.translation.height / bounds.size.height)
                    value = max(min(getPrgValue(), inRange.upperBound), inRange.lowerBound)
                }
                .onEnded { _ in
                    localRealProgress = max(min(localRealProgress + localTempProgress, 1), 0)
                    localTempProgress = 0
                }
            )
            .onChange(of: isActive) { newValue in
                value = max(min(getPrgValue(), inRange.upperBound), inRange.lowerBound)
                onEditingChanged(newValue)
            }
            .onAppear {
                localRealProgress = getPrgPercentage(value)
            }
            .onChange(of: value) { newValue in
                if !isActive {
                    localRealProgress = getPrgPercentage(newValue)
                }
            }
        }
        .frame(width: isActive ? width * 1.9 : width, alignment: .center)
        .offset(x: isActive ? -10 : 0)
        .onChange(of: value) { newValue in
            UIScreen.main.brightness = CGFloat(newValue)
        }
    }
    
    private var getIconName: String {
        let brightnessLevel = CGFloat(localRealProgress + localTempProgress)
        switch brightnessLevel {
        case ..<0.2:
            return "moon.fill"
        case 0.2..<0.38:
            return "sun.min"
        case 0.38..<0.7:
            return "sun.max"
        default:
            return "sun.max.fill"
        }
    }
    
    private var animation: Animation {
        return .spring()
    }
    
    private func getPrgPercentage(_ value: T) -> T {
        let range = inRange.upperBound - inRange.lowerBound
        let correctedStartValue = value - inRange.lowerBound
        let percentage = correctedStartValue / range
        return percentage
    }
    
    private func getPrgValue() -> T {
        return ((localRealProgress + localTempProgress) * (inRange.upperBound - inRange.lowerBound)) + inRange.lowerBound
    }
}
